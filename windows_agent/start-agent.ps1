$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot
$tokenPath = Join-Path $PSScriptRoot 'pairing-token.txt'
if (-not (Test-Path $tokenPath)) {
  $bytes = New-Object byte[] 32
  [System.Security.Cryptography.RandomNumberGenerator]::Fill($bytes)
  $token = [Convert]::ToBase64String($bytes).TrimEnd('=').Replace('+','-').Replace('/','_')
  [System.IO.File]::WriteAllText($tokenPath, $token)
} else {
  $token = (Get-Content $tokenPath -Raw).Trim()
}
$env:REMOTE_UNLOCK_TOKEN = $token
$env:REMOTE_UNLOCK_PORT = '8765'
Write-Host ''
Write-Host 'RemoteUnlock Windows Agent' -ForegroundColor Cyan
Write-Host 'Pairing token (keep private):' -ForegroundColor Yellow
Write-Host $token
Write-Host ''
Write-Host 'Agent will listen on localhost:8765. Do not expose this port directly to the public internet.' -ForegroundColor DarkYellow
node .\server.js
