#!/usr/bin/env pwsh
# PowerShell backup script - Test version without Telegram

$ErrorActionPreference = "Stop"

# Configuration
$WORKSPACE = "$env:USERPROFILE\.openclaw\workspace"
$GIT_REPO = $env:GIT_REPO
$GIT_BRANCH = "main"
$LOG_FILE = "$WORKSPACE\backup.log"

$TIMESTAMP = (Get-Date -Format "yyyy-MM-dd hh:mm tt")
$ISO_DATE = Get-Date -Format "yyyy-MM-dd"

function Log {
    param([string]$Message)
    $ts = Get-Date -Format "yyyy-MM-dd hh:mm:ss tt"
    "$ts $Message" | Tee-Object -FilePath $LOG_FILE -Append
}

try {
    Log "=== Backup started ==="
    $start_time = Get-Date

    # Validate env vars
    if ([string]::IsNullOrWhiteSpace($GIT_REPO)) { throw "GIT_REPO not set" }

    Set-Location $WORKSPACE

    # Ensure memory file exists for today
    $today_mem = "memory\$ISO_DATE.md"
    if (-not (Test-Path $today_mem)) {
        "# Memory Log - $ISO_DATE`n`n## Session Start`n**Time:** $TIMESTAMP`n**Agent:** Jarvis`n**User:** Amit`n`n### Conversation Transcript`n" | Out-File $today_mem -Encoding UTF8
        Log "Created new memory file: $today_mem"
    }

    # Update MEMORY.md timestamp
    $mem_curated = "MEMORY.md"
    if (Test-Path $mem_curated) {
        (Get-Content $mem_curated -Raw) -replace '(?s)(Last updated:).*', "Last updated: $ISO_DATE (Asia/Kolkata)" |
            Out-File $mem_curated -Encoding UTF8
    }

    # Git add & commit
    Log "Staging files..."
    git add -A memory/ MEMORY.md AGENTS.md SOUL.md USER.md IDENTITY.md TOOLS.md scripts/ systemd/ config-templates/ 2>$null

    # Check if there are changes
    $status = git status --porcelain
    if (-not $status) {
        Log "No changes to commit"
        exit 0
    }

    Log "Committing changes..."
    git commit -m "Auto-backup $TIMESTAMP" 2>&1 | ForEach-Object { Log $_ }
    if ($LASTEXITCODE -ne 0) { throw "Git commit failed" }

    # Git push with simple retry
    $retry = 0
    while ($retry -lt 2) {
        Log "Pushing to GitHub (attempt $($retry+1))..."
        git push origin $GIT_BRANCH 2>&1 | ForEach-Object { Log $_ }
        if ($LASTEXITCODE -eq 0) { break }
        $retry++
        Log "Push failed, retry in 5s..."
        Start-Sleep -Seconds 5
    }
    if ($LASTEXITCODE -ne 0) { throw "Git push failed" }

    $duration = (Get-Date) - $start_time
    $duration_sec = [int]$duration.TotalSeconds

    Log "Backup completed in $duration_sec seconds"
    exit 0
}
catch {
    Log "ERROR: $($_.Exception.Message)"
    exit 1
}
