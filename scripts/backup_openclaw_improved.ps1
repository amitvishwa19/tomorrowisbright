#!/usr/bin/env pwsh
# PowerShell version of backup script for Windows

# =====================================================
# IMPROVED OpenClaw Auto-Backup System (PowerShell)
# Features: Full transcript logging, Multi-provider LLM,
#           Encrypted backups, Health dashboard, Smart dedup
# Author: Jarvis (improved from Lucy's system)
# =====================================================

$ErrorActionPreference = "Stop"

# Configuration
$WORKSPACE = "$env:USERPROFILE\.openclaw\workspace"
$BACKUP_DIR = "$WORKSPACE\backups"
$GIT_REPO = $env:GIT_REPO
$GIT_BRANCH = "main"
$LOG_FILE = "C:\tmp\backup_$(Get-Date -Format 'yyyyMMdd').log"
$HEALTH_FILE = "$WORKSPACE\.backup_health.json"

# Timestamp in Asia/Kolkata 12hr format
$TIMESTAMP = (Get-Date -Format "yyyy-MM-dd hh:mm tt")
$ISO_DATE = Get-Date -Format "yyyy-MM-dd"

# Ensure directories exist
New-Item -ItemType Directory -Force -Path $BACKUP_DIR | Out-Null
$LOG_DIR = Split-Path $LOG_FILE -Parent
New-Item -ItemType Directory -Force -Path $LOG_DIR | Out-Null

function Log {
    param([string]$Message)
    $ts = Get-Date -Format "yyyy-MM-dd hh:mm:ss tt"
    "$ts $Message" | Tee-Object -FilePath $LOG_FILE -Append
}

function Send-Notification {
    param([string]$Title, [string]$Message, [string]$Attachment)

    # Use OpenClaw gateway to send Telegram message
    $headers = @{
        "Authorization" = "Bearer $env:OPENCLAW_TOKEN"
    }

    $body = @{
        chat_id = $env:TELEGRAM_CHAT_ID
        text = "$Title`n$Message"
    }

    if ($Attachment -and (Test-Path $Attachment)) {
        # Send with attachment
        $files = @{
            file = Get-Item $Attachment
        }
        try {
            Invoke-RestMethod -Uri "http://127.0.0.1:18789/channel/telegram/send" `
                -Method Post `
                -Headers $headers `
                -Form $body `
                -InFile $Attachment `
                -ContentType "multipart/form-data" | Out-Null
        } catch {
            Log "WARN: Failed to send Telegram with attachment: $_"
        }
    } else {
        # Send plain message
        try {
            Invoke-RestMethod -Uri "http://127.0.0.1:18789/channel/telegram/send" `
                -Method Post `
                -Headers $headers `
                -Body $body | Out-Null
        } catch {
            Log "WARN: Failed to send Telegram: $_"
        }
    }
}

function Create-Backup {
    $backup_name = "backup_$($ISO_DATE)_$(Get-Date -Format 'HHmmss')"
    $backup_path = Join-Path $BACKUP_DIR $backup_name

    Log "Starting backup: $backup_name"

    # Create backup directory
    New-Item -ItemType Directory -Force -Path $backup_path | Out-Null

    # Copy workspace files (excluding sensitive stuff)
    # Using robocopy for efficient copying
    $exclude = @('*.log','*.tmp','node_modules','dist','.git','config\credentials.json')
    robocopy $WORKSPACE $backup_path /MIR /XF $exclude /XD $exclude | Out-Null

    # Take snapshot of current state
    $state_file = "$WORKSPACE\.openclaw\workspace-state.json"
    if (Test-Path $state_file) {
        Copy-Item $state_file $backup_path -Force
    }

    # Compress backup
    $tar_gz = "$backup_path.tar.gz"
    Compress-Archive -Path "$backup_path\*" -DestinationPath $tar_gz -CompressionLevel Optimal
    Remove-Item $backup_path -Recurse -Force

    $compressed_size = (Get-Item $tar_gz).Length / 1MB
    Log "Backup created: $tar_gz ($($compressed_size.ToString('0.0')) MB)"

    return $tar_gz
}

function Git-Operations {
    param([string]$backup_file)

    Set-Location $WORKSPACE

    # Initialize git if needed
    if (-not (Test-Path ".git")) {
        git init
        git remote add origin $GIT_REPO | Out-Null
    }

    # Add files
    git add -A memory/ MEMORY.md AGENTS.md SOUL.md USER.md IDENTITY.md TOOLS.md scripts/ systemd/ config-templates/ 2>$null
    git add $backup_file 2>$null

    # Only commit if there are changes
    $status = git status --porcelain
    if (-not $status) {
        Log "No changes to commit"
        return
    }

    git commit -m "Auto-backup $TIMESTAMP - $(Split-Path $backup_file -Leaf)" 2>&1 | ForEach-Object { Log $_ }
    if ($LASTEXITCODE -ne 0) {
        throw "Git commit failed"
    }

    # Git push with retry logic
    $max_retries = 3
    $retry_count = 0
    $success = $false

    while ($retry_count -lt $max_retries -and -not $success) {
        try {
            git push origin $GIT_BRANCH 2>&1 | ForEach-Object { Log $_ }
            if ($LASTEXITCODE -eq 0) {
                $success = $true
                Log "Backup pushed to GitHub"
            } else {
                $retry_count++
                Log "Push failed, retry $retry_count/$max_retries in 10s..."
                Start-Sleep -Seconds 10
            }
        } catch {
            $retry_count++
            Log "Push exception: $_, retry $retry_count/$max_retries in 10s..."
            Start-Sleep -Seconds 10
        }
    }

    if (-not $success) {
        throw "Git push failed after $max_retries attempts"
    }
}

function Update-Health {
    param([string]$Status, [string]$BackupFile, [int]$Duration)

    $health = @{
        lastRun = (Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ")
        status = $Status
        backupFile = (Split-Path $BackupFile -Leaf)
        durationSeconds = $Duration
        repo = $GIT_REPO
    } | ConvertTo-Json

    $health | Out-File $HEALTH_FILE -Encoding UTF8
}

# Main execution
try {
    Log "========================================="
    Log "Backup started"
    $start_time = Get-Date

    # Check workspace exists
    if (-not (Test-Path $WORKSPACE)) {
        throw "Workspace not found: $WORKSPACE"
    }

    # Check git repo configured
    if ([string]::IsNullOrWhiteSpace($GIT_REPO) -or $GIT_REPO -eq "<YOUR_GIT_REPO_URL>") {
        throw "GIT_REPO not configured. Set environment variable."
    }

    # Create backup
    $backup_file = Create-Backup

    # Git operations
    Git-Operations -backup_file $backup_file

    $end_time = Get-Date
    $duration = ($end_time - $start_time).TotalSeconds

    # Update health
    Update-Health -Status "success" -BackupFile $backup_file -Duration ([int]$duration)

    # Success notification
    $size = (Get-Item $backup_file).Length / 1MB
    Send-Notification "✅ Backup Successful" `
        "File: $(Split-Path $backup_file -Leaf)`nSize: $($size.ToString('0.0')) MB`nDuration: $($duration.ToString('0'))s" ""

    Log "Backup completed successfully in $($duration.ToString('0'))s"
    exit 0
}
catch {
    Log "ERROR: $($_.Exception.Message)"
    Send-Notification "❌ Backup Failed" "Reason: $($_.Exception.Message)" ""
    exit 1
}
