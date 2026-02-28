#!/usr/bin/env pwsh
# Install OpenClaw Gateway as Windows Service using NSSM

param(
    [string]$NssmPath = "C:\nssm\nssm.exe",
    [string]$GatewayPort = "18789",
    [string]$GatewayToken = $env:OPENCLAW_TOKEN
)

Write-Host "=== OpenClaw Gateway Windows Service Installer ==="
Write-Host ""

# Check NSSM exists
if (-not (Test-Path $NssmPath)) {
    Write-Host "NSSM not found at $NssmPath"
    Write-Host "Please download from https://nssm.cc/download and extract to C:\nssm"
    exit 1
}

# Check gateway token
if ([string]::IsNullOrWhiteSpace($GatewayToken)) {
    Write-Host "OPENCLAW_TOKEN environment variable not set!"
    Write-Host "Set it first: [System.Environment]::SetEnvironmentVariable('OPENCLAW_TOKEN','YOUR_TOKEN','User')"
    exit 1
}

# Paths
$NodeExe = "C:\Program Files\nodejs\node.exe"
$GatewayScript = "$env:USERPROFILE\AppData\Roaming\npm\node_modules\openclaw\dist\index.js"
$WorkingDir = "$env:USERPROFILE\.openclaw"

# Verify node exists
if (-not (Test-Path $NodeExe)) {
    Write-Host "Node.js not found at $NodeExe"
    Write-Host "Install Node.js first: https://nodejs.org/"
    exit 1
}

# Verify gateway script exists
if (-not (Test-Path $GatewayScript)) {
    Write-Host "OpenClaw gateway script not found:"
    Write-Host "  $GatewayScript"
    Write-Host "Make sure OpenClaw is installed globally: npm i -g openclaw"
    exit 1
}

Write-Host "Installing OpenClaw Gateway as Windows service..."
Write-Host "Service name: OpenClawGateway"
Write-Host "Port: $GatewayPort"
Write-Host ""

# Install service
& $NssmPath install OpenClawGateway $NodeExe "`"$GatewayScript`" gateway --port $GatewayPort" | Out-Null

if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: NSSM install failed"
    exit 1
}

# Set service parameters
& $NssmPath set OpenClawGateway AppDirectory $WorkingDir | Out-Null
& $NssmPath set OpenClawGateway AppEnvironment "OPENCLAW_GATEWAY_PORT=$GatewayPort;OPENCLAW_TOKEN=$GatewayToken" | Out-Null
& $NssmPath set OpenClawGateway AppRestartDelay 5000 | Out-Null
& $NssmPath set OpenClawGateway AppExit Default Restart | Out-Null
& $NssmPath set OpenClawGateway Start SERVICE_AUTO_START | Out-Null
& $NssmPath set OpenClawGateway AppStdout "$WorkingDir\logs\gateway.stdout.log" | Out-Null
& $NssmPath set OpenClawGateway AppStderr "$WorkingDir\logs\gateway.stderr.log" | Out-Null
& $NssmPath set OpenClawGateway AppRotateFiles 1 | Out-Null
& $NssmPath set OpenClawGateway AppRotateOnline 1 | Out-Null

# Ensure logs directory exists
New-Item -ItemType Directory -Force -Path "$WorkingDir\logs" | Out-Null

Write-Host "Service installed successfully!"
Write-Host ""
Write-Host "Next steps:"
Write-Host "1. Start the service: & `"$NssmPath`" start OpenClawGateway"
Write-Host "2. Check status: & `"$NssmPath`" status OpenClawGateway"
Write-Host "3. View logs: Get-Content `"$WorkingDir\logs\gateway.stdout.log`" -Tail 50 -Wait"
Write-Host ""
Write-Host "To uninstall: & `"$NssmPath`" remove OpenClawGateway confirm"
