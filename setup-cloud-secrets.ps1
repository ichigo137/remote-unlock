$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
$secretPath = Join-Path $root 'cloud-secrets.json'
$envPath = Join-Path $root 'cloud-secrets.env'

if (-not (Test-Path $secretPath)) {
  function New-UrlSafeSecret {
    $bytes = New-Object byte[] 32
    $rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
    $rng.GetBytes($bytes)
    $rng.Dispose()
    return [Convert]::ToBase64String($bytes).TrimEnd('=').Replace('+','-').Replace('/','_')
  }

  $secrets = [ordered]@{
    commandSecret = New-UrlSafeSecret
    deviceSecret = New-UrlSafeSecret
  }
  $secrets | ConvertTo-Json | Set-Content -Path $secretPath -Encoding UTF8
  Write-Host 'Generated two independent 256-bit secrets.' -ForegroundColor Green
} else {
  $secrets = Get-Content $secretPath -Raw | ConvertFrom-Json
  Write-Host 'Reusing existing secrets; no rotation performed.' -ForegroundColor Yellow
}

@(
  ('REMOTE_UNLOCK_COMMAND_SECRET=' + $secrets.commandSecret),
  ('REMOTE_UNLOCK_DEVICE_SECRET=' + $secrets.deviceSecret)
) | Set-Content -Path $envPath -Encoding ASCII

Write-Host ''
Write-Host 'Secrets saved locally in cloud-secrets.env (ignored by Git).' -ForegroundColor Green
Write-Host 'After linking the Supabase project, upload them with:' -ForegroundColor Cyan
Write-Host 'supabase secrets set --env-file ./cloud-secrets.env'
Write-Host ''
Write-Host 'Command secret for the Android app:' -ForegroundColor Yellow
Write-Host $secrets.commandSecret
Write-Host ''
Write-Host 'Keep cloud-secrets.json and cloud-secrets.env private. Never commit or share them.'
Write-Host ''

$endpoint = Read-Host 'Paste the deployed Edge Function URL (https://<project>.supabase.co/functions/v1/remoteunlock), or leave blank to configure later'
$publishableKey = Read-Host 'Paste the Supabase publishable key, or leave blank to configure later'

if ($endpoint -and $publishableKey) {
  $uri = $null
  if (-not [Uri]::TryCreate($endpoint, [UriKind]::Absolute, [ref]$uri) -or
      $uri.Scheme -ne 'https' -or
      -not $uri.AbsolutePath.EndsWith('/functions/v1/remoteunlock')) {
    throw 'The endpoint must be the full HTTPS URL ending in /functions/v1/remoteunlock.'
  }

  $agentConfig = [ordered]@{
    endpoint = $endpoint.TrimEnd('/')
    publishableKey = $publishableKey.Trim()
    deviceSecret = [string]$secrets.deviceSecret
    pollIntervalMs = 10000
  }
  $agentConfig | ConvertTo-Json | Set-Content -Path (Join-Path $root 'windows_agent\agent-config.json') -Encoding UTF8
  Write-Host ''
  Write-Host 'Windows agent config saved to windows_agent\agent-config.json.' -ForegroundColor Green
} else {
  Write-Host 'Agent config was not created. Re-run this script after the cloud function is deployed.' -ForegroundColor Yellow
}
