$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot

$configPath = Join-Path $PSScriptRoot 'agent-config.json'
if (-not (Test-Path $configPath)) {
  Write-Host 'Agent configuration is missing.' -ForegroundColor Yellow
  Write-Host 'Run ..\setup-cloud-secrets.ps1 after creating/deploying the Supabase relay, then try again.'
  exit 1
}

$config = Get-Content $configPath -Raw | ConvertFrom-Json
if (-not $config.endpoint -or -not $config.publishableKey -or -not $config.deviceSecret) {
  Write-Host 'agent-config.json is incomplete. Re-run ..\setup-cloud-secrets.ps1.' -ForegroundColor Red
  exit 1
}

$env:REMOTE_UNLOCK_ENDPOINT = [string]$config.endpoint
$env:REMOTE_UNLOCK_PUBLISHABLE_KEY = [string]$config.publishableKey
$env:REMOTE_UNLOCK_DEVICE_SECRET = [string]$config.deviceSecret
if ($config.pollIntervalMs) { $env:REMOTE_UNLOCK_POLL_MS = [string]$config.pollIntervalMs }

node .\server.js
