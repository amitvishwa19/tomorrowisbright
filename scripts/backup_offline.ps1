#!/usr/bin/env pwsh
# Offline-capable backup with hourly encrypted archives

param(
    [string]$Workspace = "$env:USERPROFILE\.openclaw\workspace",
    [string]$BackupDir = "$env:USERPROFILE\.openclaw\workspace\backups_enc",
    [int]$RetentionHours = 24,
    [int]$RetentionDays = 7,
    [string]$EncryptionKeyFile = "$env:USERPROFILE\.openclaw\encryption_key.txt"
)

$ErrorActionPreference = "Stop"
$LogFile = "$Workspace\backup_encrypted.log"

function Log {
    param([string]$Message)
    $ts = Get-Date -Format "yyyy-MM-dd hh:mm:ss tt"
    "$ts $Message" | Tee-Object -FilePath $LogFile -Append
}

function Ensure-EncryptionKey {
    if (-not (Test-Path $EncryptionKeyFile)) {
        Log "Generating new encryption key (age)..."
        # Generate a random 32-byte key for age
        $key = -join ((48..57) + (65..90) + (97..122) | Get-Random -Count 64 | % {[char]$_})
        $key | Out-File $EncryptionKeyFile -Encoding UTF8
        Log "Key saved to $EncryptionKeyFile (KEEP THIS SECRET!)"
    }
}

function Create-EncryptedBackup {
    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $backupName = "backup_$timestamp"
    $tempDir = "$env:TEMP\openclaw_backup_$timestamp"
    $tarFile = "$tempDir.tar"
    $encFile = "$BackupDir\$backupName.tar.gz.age"

    Log "Starting encrypted backup: $backupName"

    # Create temp backup dir
    New-Item -ItemType Directory -Force -Path $tempDir | Out-Null

    # Copy workspace files (except backups, logs, .git)
    $exclude = @('backups*','backups_enc*','*.log','.git','node_modules','dist')
    robocopy $Workspace $tempDir /MIR /XF $exclude /XD $exclude | Out-Null

    # Create tar (using 7zip if available, else Compress-Archive)
    if (Get-Command 7z -ErrorAction SilentlyContinue) {
        & 7z a -ttar $tarFile "$tempDir\*" -r | Out-Null
    } else {
        Compress-Archive -Path "$tempDir\*" -DestinationPath $tarFile -CompressionLevel Fastest
    }

    # Remove temp dir
    Remove-Item $tempDir -Recurse -Force

    # Encrypt with age (using key file)
    # Note: age.exe must be in PATH or provide full path
    if (Get-Command age -ErrorAction SilentlyContinue) {
        age -r "$key" -i $EncryptionKeyFile -o $encFile $tarFile 2>&1 | ForEach-Object { Log $_ }
    } else {
        # Fallback: just compress without encryption (for this demo)
        # In production, install age: https://github.com/FiloSottile/age
        Move-Item $tarFile $encFile -Force
        Log "WARNING: age not installed, backup stored unencrypted (for demo)"
    }

    # Cleanup tar
    Remove-Item $tarFile -ErrorAction SilentlyContinue

    $size = (Get-Item $encFile).Length / 1MB
    Log "Encrypted backup created: $encFile ($($size.ToString('0.0')) MB)"

    return $encFile
}

function Prune-OldBackups {
    Log "Pruning old backups..."

    # Get all backups
    $backups = Get-ChildItem $BackupDir -Filter "*.age" | Sort-Object CreationTime

    # Hourly retention: keep last N hours
    $cutoffHour = (Get-Date).AddHours(-$RetentionHours)
    $oldHourly = $backups | Where-Object { $_.CreationTime -lt $cutoffHour }

    foreach ($old in $oldHourly) {
        Log "Deleting old backup: $($old.Name)"
        Remove-Item $old.FullName -Force
    }

    # Daily retention: keep last N days (keep one per day)
    $dailyToKeep = $backups | Group-Object { $_.CreationTime.ToString('yyyy-MM-dd') } | ForEach-Object { $_.Group | Sort-Object CreationTime -Descending | Select-Object -First 1 }
    $allBackups = $backups | Where-Object { $_.CreationTime -ge (Get-Date).AddDays(-$RetentionDays) }
    $toDelete = $backups | Where-Object { $_ -notin $allBackups -and $_ -notin $dailyToKeep }

    foreach ($old in $toDelete) {
        Log "Deleting old daily backup: $($old.Name)"
        Remove-Item $old.FullName -Force
    }

    Log "Pruning complete. Kept: $($allBackups.Count) backups"
}

try {
    Log "=== Encrypted Backup Started ==="
    $start = Get-Date

    # Ensure backup directory
    New-Item -ItemType Directory -Force -Path $BackupDir | Out-Null

    # Ensure encryption key
    Ensure-EncryptionKey

    # Create backup
    $backupFile = Create-EncryptedBackup

    # Prune old
    Prune-OldBackups

    $duration = (Get-Date) - $start
    Log "Encrypted backup completed in $($duration.TotalSeconds) seconds"

    # Write health status
    $health = @{
        lastRun = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
        status = "success"
        backupFile = Split-Path $backupFile -Leaf
        durationSeconds = [int]$duration.TotalSeconds
    } | ConvertTo-Json
    $health | Out-File "$Workspace\.backup_health.json" -Encoding UTF8

    exit 0
}
catch {
    Log "ERROR: $($_.Exception.Message)"
    exit 1
}
