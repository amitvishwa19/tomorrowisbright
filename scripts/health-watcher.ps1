#!/usr/bin/env pwsh
# Health Watcher - monitors OpenClaw gateway and restarts if down

param(
    [string]$GatewayUrl = "http://127.0.0.1:18789/health",
    [string]$NssmPath = "C:\nssm\nssm.exe",
    [int]$CheckIntervalSeconds = 10,
    [int]$MaxRetries = 3,
    [string]$LogFile = "$env:USERPROFILE\.openclaw\workspace\health-watcher.log"
)

$ErrorActionPreference = "Continue"

function Log {
    param([string]$Message)
    $ts = Get-Date -Format "yyyy-MM-dd hh:mm:ss tt"
    "$ts $Message" | Tee-Object -FilePath $LogFile -Append
}

function Check-Gateway {
    try {
        $response = Invoke-RestMethod -Uri $GatewayUrl -Method Get -TimeoutSec 5 -ErrorAction Stop
        if ($response.status -eq 'healthy' -or $response.Status -eq 'healthy') {
            return $true
        }
        return $false
    } catch {
        return $false
    }
}

function Restart-Gateway {
    Log "Attempting to restart OpenClawGateway service..."
    if (Test-Path $NssmPath) {
        & $NssmPath restart OpenClawGateway 2>&1 | ForEach-Object { Log $_ }
        if ($LASTEXITCODE -eq 0) {
            Log "Restart command issued successfully"
            return $true
        }
    } else {
        Log "NSSM not found at $NssmPath, cannot restart service"
    }
    return $false
}

Log "=== Health Watcher Started ==="
Log "Monitoring: $GatewayUrl"
Log "Check interval: ${CheckIntervalSeconds}s"

$consecutiveFailures = 0
$lastRestartTime = Get-Date

while ($true) {
    $isHealthy = Check-Gateway

    if ($isHealthy) {
        if ($consecutiveFailures -gt 0) {
            Log "Gateway is healthy again (after $consecutiveFailures failures)"
        }
        $consecutiveFailures = 0
    } else {
        $consecutiveFailures++
        Log "Health check FAILED (consecutive: $consecutiveFailures)"

        if ($consecutiveFailures -ge $MaxRetries) {
            Log "MAX FAILURES REACHED ($MaxRetries) - initiating restart"

            # Avoid restarting too frequently (rate limit)
            $timeSinceLastRestart = (Get-Date) - $lastRestartTime
            if ($timeSinceLastRestart.TotalMinutes -lt 2) {
                Log "Throttling restart (last restart was $($timeSinceLastRestart.TotalMinutes) minutes ago)"
            } else {
                if (Restart-Gateway) {
                    $consecutiveFailures = 0
                    $lastRestartTime = Get-Date
                }
            }
        }
    }

    Start-Sleep -Seconds $CheckIntervalSeconds
}
