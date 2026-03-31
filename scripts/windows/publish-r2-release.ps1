param(
  [string]$BucketName = $env:R2_BUCKET_NAME,
  [string]$EndpointUrl = $env:R2_ENDPOINT_URL,
  [string]$PublicBaseUrl = $env:R2_PUBLIC_BASE_URL,
  [string]$ReleaseNotes = "Actualizacion de version.",
  [switch]$BuildAndroid,
  [switch]$BuildWindows,
  [switch]$SkipBuild
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Assert-Command([string]$CommandName, [string]$Hint) {
  if (-not (Get-Command $CommandName -ErrorAction SilentlyContinue)) {
    throw "Missing command '$CommandName'. $Hint"
  }
}

function Get-AppVersion([string]$PubspecPath) {
  $match = Select-String -Path $PubspecPath -Pattern '^version:\s*([0-9]+\.[0-9]+\.[0-9]+)\+'
  if (-not $match) {
    throw "Could not parse app version from $PubspecPath"
  }
  return $match.Matches[0].Groups[1].Value
}

function Set-InnoVersion([string]$IssPath, [string]$Version) {
  $content = Get-Content -Path $IssPath -Raw
  $content = [System.Text.RegularExpressions.Regex]::Replace(
    $content,
    '(?m)^AppVersion=.*$',
    "AppVersion=$Version"
  )
  $content = [System.Text.RegularExpressions.Regex]::Replace(
    $content,
    '(?m)^OutputBaseFilename=.*$',
    "OutputBaseFilename=Kumoriya-$Version-windows-x64-setup"
  )
  Set-Content -Path $IssPath -Value $content -NoNewline
}

function Upload-FileToR2(
  [string]$FilePath,
  [string]$Bucket,
  [string]$Key,
  [string]$Endpoint
) {
  Write-Host "Uploading: $FilePath -> s3://$Bucket/$Key"
  aws s3 cp "$FilePath" "s3://$Bucket/$Key" --endpoint-url "$Endpoint" --region auto
}

if ([string]::IsNullOrWhiteSpace($BucketName)) {
  throw "BucketName missing. Set -BucketName or env:R2_BUCKET_NAME"
}
if ([string]::IsNullOrWhiteSpace($EndpointUrl)) {
  throw "EndpointUrl missing. Set -EndpointUrl or env:R2_ENDPOINT_URL"
}
if ([string]::IsNullOrWhiteSpace($PublicBaseUrl)) {
  throw "PublicBaseUrl missing. Set -PublicBaseUrl or env:R2_PUBLIC_BASE_URL"
}

if (-not $BuildAndroid -and -not $BuildWindows) {
  $BuildAndroid = $true
  $BuildWindows = $true
}

Assert-Command -CommandName "aws" -Hint "Install AWS CLI: winget install Amazon.AWSCLI"
Assert-Command -CommandName "flutter" -Hint "Install Flutter SDK and ensure flutter is in PATH"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = Resolve-Path (Join-Path $scriptDir "..\..")
$appDir = Join-Path $repoRoot "apps\kumoriya_app"
$pubspecPath = Join-Path $appDir "pubspec.yaml"
$issPath = Join-Path $appDir "windows\kumoriya_installer.iss"

$version = Get-AppVersion -PubspecPath $pubspecPath
$tag = "v$version"

$apkOutPath = Join-Path $appDir "build\app\outputs\flutter-apk\app-release.apk"
$setupFileName = "Kumoriya-$version-windows-x64-setup.exe"
$setupOutPath = Join-Path $appDir "build\windows\installer\$setupFileName"

Push-Location $appDir
try {
  if (-not $SkipBuild) {
    if ($BuildAndroid) {
      Write-Host "Building Android APK..."
      flutter build apk --release
    }

    if ($BuildWindows) {
      Write-Host "Building Windows runner..."
      flutter build windows --release

      Assert-Command -CommandName "iscc" -Hint "Install Inno Setup and add ISCC to PATH"
      Set-InnoVersion -IssPath $issPath -Version $version

      Write-Host "Building Inno installer..."
      iscc "$issPath" /Qp
    }
  }
}
finally {
  Pop-Location
}

if ($BuildAndroid -and -not (Test-Path $apkOutPath)) {
  throw "APK not found at $apkOutPath"
}
if ($BuildWindows -and -not (Test-Path $setupOutPath)) {
  throw "Windows installer not found at $setupOutPath"
}

$androidFileName = "kumoriya-$version.apk"
$androidKey = "artifacts/android/$tag/$androidFileName"
$windowsKey = "artifacts/windows/$tag/$setupFileName"
$releaseJsonKey = "releases/$tag/release.json"
$changelogEsKey = "releases/changelogs/es/$tag.md"
$changelogEnKey = "releases/changelogs/en/$tag.md"

$releaseDir = Join-Path $repoRoot "releases\versions\$tag"
New-Item -ItemType Directory -Path $releaseDir -Force | Out-Null

$releaseJsonPath = Join-Path $releaseDir "release.json"
$updateManifestPath = Join-Path $repoRoot "releases\manifests\update.json"
$releaseNotesEsPath = Join-Path $repoRoot "docs\releases\es\$tag.md"
$releaseNotesEnPath = Join-Path $repoRoot "docs\releases\en\$tag.md"

$androidUrl = "$PublicBaseUrl/$androidKey"
$windowsUrl = "$PublicBaseUrl/$windowsKey"

$releaseMeta = @{
  version = $version
  tag = $tag
  date = (Get-Date -Format "yyyy-MM-dd")
  channels = @("alpha")
  artifacts = @{
    android = @{
      file_name = $androidFileName
      r2_key = $androidKey
      public_url = $androidUrl
    }
    windows = @{
      file_name = $setupFileName
      r2_key = $windowsKey
      public_url = $windowsUrl
    }
  }
  changelog_paths = @{
    es = "docs/releases/es/$tag.md"
    en = "docs/releases/en/$tag.md"
  }
}
$releaseMeta | ConvertTo-Json -Depth 8 | Set-Content -Path $releaseJsonPath

$updateManifest = @{
  android = @{
    latest_version = $version
    url = $androidUrl
    release_notes = $ReleaseNotes
  }
  windows = @{
    latest_version = $version
    url = $windowsUrl
    release_notes = $ReleaseNotes
  }
}
$updateManifest | ConvertTo-Json -Depth 8 | Set-Content -Path $updateManifestPath

if ($BuildAndroid) {
  $tempAndroidPath = Join-Path $env:TEMP $androidFileName
  Copy-Item -Path $apkOutPath -Destination $tempAndroidPath -Force
  Upload-FileToR2 -FilePath $tempAndroidPath -Bucket $BucketName -Key $androidKey -Endpoint $EndpointUrl
}

if ($BuildWindows) {
  Upload-FileToR2 -FilePath $setupOutPath -Bucket $BucketName -Key $windowsKey -Endpoint $EndpointUrl
}

Upload-FileToR2 -FilePath $releaseJsonPath -Bucket $BucketName -Key $releaseJsonKey -Endpoint $EndpointUrl
Upload-FileToR2 -FilePath $updateManifestPath -Bucket $BucketName -Key "update.json" -Endpoint $EndpointUrl

if (Test-Path $releaseNotesEsPath) {
  Upload-FileToR2 -FilePath $releaseNotesEsPath -Bucket $BucketName -Key $changelogEsKey -Endpoint $EndpointUrl
}

if (Test-Path $releaseNotesEnPath) {
  Upload-FileToR2 -FilePath $releaseNotesEnPath -Bucket $BucketName -Key $changelogEnKey -Endpoint $EndpointUrl
}

Write-Host ""
Write-Host "Release published successfully."
Write-Host "Version: $version"
if ($BuildAndroid) { Write-Host "Android URL: $androidUrl" }
if ($BuildWindows) { Write-Host "Windows URL: $windowsUrl" }
Write-Host "Manifest URL: $PublicBaseUrl/update.json"
