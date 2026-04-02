param(
  [string]$OutputDir = "$PSScriptRoot\..\..\logs\android_runs",
  [string]$Serial = "",
  [switch]$ClearLogcat
)

$ErrorActionPreference = "Stop"

$timestamp = Get-Date -Format "yyyy-MM-dd_HHmmss"
$runId = "android_$timestamp"
$logFile = Join-Path $OutputDir "downloads_$runId.log"

if (-not (Test-Path $OutputDir)) {
  New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
}

if (-not (Get-Command adb -ErrorAction SilentlyContinue)) {
  throw "adb no esta disponible en PATH. Instala Android Platform Tools o abre una terminal con adb configurado."
}

$adbArgsBase = @()
if ($Serial -ne "") {
  $adbArgsBase += @("-s", $Serial)
}

$adbState = (& adb @adbArgsBase get-state 2>$null)
if ($LASTEXITCODE -ne 0 -or $adbState -notmatch "device") {
  throw "No hay dispositivo Android listo (device). Verifica USB debugging, cable y autorizacion ADB."
}

if ($ClearLogcat) {
  & adb @adbArgsBase logcat -c
}

$packageCandidates = @(
  "dev.kumoriya.app.debug",
  "dev.kumoriya.app"
)

function Get-LatestDeviceLogPath {
  foreach ($packageName in $packageCandidates) {
    $logDir = "/sdcard/Android/data/$packageName/files/Kumoriya/logs"
    & adb @adbArgsBase shell test -d $logDir 2>$null
    if ($LASTEXITCODE -eq 0) {
      $probe = & adb @adbArgsBase shell find $logDir -maxdepth 1 -type f 2>$null
      $devicePath = $probe |
        Where-Object { $_ -like "*/downloads_*.log" } |
        Sort-Object -Descending |
        Select-Object -First 1
      if ($devicePath) {
        return @{ Package = $packageName; Path = $devicePath.Trim() }
      }
    }
  }

  return $null
}

"Kumoriya Android Download Log Capture" | Tee-Object -FilePath $logFile
"RunId: $runId" | Tee-Object -FilePath $logFile -Append
"Started: $(Get-Date -Format o)" | Tee-Object -FilePath $logFile -Append
"Mode: polling Android app log file and syncing it to this PC" | Tee-Object -FilePath $logFile -Append
"Press Ctrl+C to stop capture after reproducing the issue." | Tee-Object -FilePath $logFile -Append
"Output: $logFile" | Tee-Object -FilePath $logFile -Append
"" | Tee-Object -FilePath $logFile -Append

$lastDevicePath = ""
$lastContentLength = -1
$hasWrittenDeviceLog = $false

while ($true) {
  $latest = Get-LatestDeviceLogPath

  if ($null -eq $latest) {
    if (-not $hasWrittenDeviceLog) {
      Write-Host "Waiting for Android log file... open the app and reproduce the issue."
    }
    Start-Sleep -Seconds 2
    continue
  }

  $devicePath = $latest.Path
  $packageName = $latest.Package
  $deviceContent = & adb @adbArgsBase shell cat $devicePath
  if ($LASTEXITCODE -ne 0) {
    Start-Sleep -Seconds 2
    continue
  }

  $contentText = ($deviceContent -join [Environment]::NewLine)
  if ($devicePath -ne $lastDevicePath -or $contentText.Length -ne $lastContentLength) {
    @(
      "Kumoriya Android Download Log Capture",
      "RunId: $runId",
      "Captured: $(Get-Date -Format o)",
      "Package: $packageName",
      "DeviceLog: $devicePath",
      "",
      $contentText
    ) | Set-Content -Path $logFile

    $lastDevicePath = $devicePath
    $lastContentLength = $contentText.Length
    $hasWrittenDeviceLog = $true
    Write-Host "Synced $devicePath -> $logFile"
  }

  Start-Sleep -Seconds 2
}
