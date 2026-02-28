#!/usr/bin/env pwsh
# Background Cloud Sync - syncs local memory to GitHub when online

param(
    [string]$Workspace = "$env:USERPROFILE\.openclaw\workspace",
    [string]$GitRepo = $env:GIT_REPO,
    [string]$LogFile = "$env:USERPROFILE\.openclaw\workspace\cloud-sync.log",
    [int]$CheckIntervalSeconds = 300  # 5 minutes
)

$ErrorActionPreference = "Continue"

function Log {
    param([string]$Message)
    $ts = Get-Date -Format "yyyy-MM-dd hh:mm:ss tt"
    "$ts $Message" | Tee-Object -FilePath $LogFile -Append
}

function Test-Online {
    # Simple connectivity test
    try {
        $null = Test-Connection github.com -Count 1 -Quiet -ErrorAction Stop
        return $true
    } catch {
        return $false
    }
}

function Sync-ToGit {
    Log "Starting cloud sync..."

    Set-Location $Workspace

    # Check if there are uncommitted changes
    $status = git status --porcelain
    if (-not $status) {
        Log "No changes to sync"
        return $false
    }

    Log "Changes detected, syncing..."

    # Stage everything important (exclude backups, logs)
    git add -A memory/ MEMORY.md AGENTS.md SOUL.md USER.md IDENTITY.md TOOLS.md 2>$null

    # Commit with timestamp
    $timestamp = Get-Date -Format "yyyy-MM-dd hh:mm:ss tt"
    git commit -m "Cloud sync $timestamp" 2>&1 | ForEach-Object { Log $_ }
    if ($LASTEXITCODE -ne 0) {
        Log "ERROR: Git commit failed during sync"
        return $false
    }

    # Push with retry
    $retry = 0
    $maxRetry = 3
    while ($retry -lt $maxRetry) {
        git push origin main 2>&1 | ForEach-Object { Log $_ }
        if ($LASTEXITCODE -eq 0) {
            Log "Cloud sync successful"
            return $true
        }
        $retry++
        Log "Push failed, retry $retry/$maxRetry in 10s..."
        Start-Sleep -Seconds 10
    }

    Log "ERROR: Cloud sync failed after $maxRetry attempts"
    return $false
}

Log "=== Cloud Sync Service Started ==="
Log "Repo: $GitRepo"
Log "Check interval: ${CheckIntervalSeconds}s"

while ($true) {
    if (Test-Online) {
        try {
            Sync-ToGit | Out-Null
        } catch {
            Log "Sync error: $($_.Exception.Message)"
        }
    } else {
        Log "Offline - skipping sync"
    }

    Start-Sleep -Seconds $CheckIntervalSeconds
}
