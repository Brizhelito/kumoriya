param(
  [string]$EnvFilePath = "secrets/kumoriya_r2.credentials.env"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if (-not (Test-Path $EnvFilePath)) {
  throw "Credentials file not found: $EnvFilePath"
}

$lines = Get-Content -Path $EnvFilePath

foreach ($line in $lines) {
  $trimmed = $line.Trim()
  if ([string]::IsNullOrWhiteSpace($trimmed)) { continue }
  if ($trimmed.StartsWith("#")) { continue }

  $parts = $trimmed -split "=", 2
  if ($parts.Count -ne 2) { continue }

  $key = $parts[0].Trim()
  $value = $parts[1].Trim()

  if ([string]::IsNullOrWhiteSpace($key)) { continue }
  [System.Environment]::SetEnvironmentVariable($key, $value, "Process")
}

Write-Host "R2 credentials loaded into current PowerShell session."
Write-Host "R2_BUCKET_NAME=$env:R2_BUCKET_NAME"
Write-Host "R2_ENDPOINT_URL=$env:R2_ENDPOINT_URL"
Write-Host "R2_PUBLIC_BASE_URL=$env:R2_PUBLIC_BASE_URL"
