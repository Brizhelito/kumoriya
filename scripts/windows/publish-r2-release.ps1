param(
  [string]$BucketName = "",
  [string]$EndpointUrl = "",
  [string]$PublicBaseUrl = "",
  [string]$ApiBaseUrl = "",
  [string]$PublishToken = "",
  [string]$Channel = "",
  [string]$ReleaseNotes = "Actualizacion de version.",
  [string]$SummaryEs = "",
  [string]$SummaryEn = "",
  [string]$R2EnvFilePath = "secrets/kumoriya_r2.credentials.env",
  [string]$UpdateEnvFilePath = "secrets/update_publish.credentials.env",
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

function Import-EnvFile([string]$Path) {
  if ([string]::IsNullOrWhiteSpace($Path) -or -not (Test-Path $Path)) {
    return
  }

  $lines = Get-Content -Path $Path
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
  [string]$Endpoint,
  [string]$ContentType,
  [string]$ContentDisposition
) {
  Write-Host "Uploading: $FilePath -> s3://$Bucket/$Key"
  $cmd = @("s3", "cp", "$FilePath", "s3://$Bucket/$Key", "--endpoint-url", "$Endpoint", "--region", "auto")
  if ($ContentType) {
    $cmd += @("--content-type", "$ContentType")
  }
  if ($ContentDisposition) {
    $cmd += @("--content-disposition", "$ContentDisposition")
  }
  aws @cmd
}

Import-EnvFile -Path $R2EnvFilePath
Import-EnvFile -Path $UpdateEnvFilePath

if ([string]::IsNullOrWhiteSpace($BucketName)) {
  $BucketName = $env:R2_BUCKET_NAME
}
if ([string]::IsNullOrWhiteSpace($EndpointUrl)) {
  $EndpointUrl = $env:R2_ENDPOINT_URL
}
if ([string]::IsNullOrWhiteSpace($PublicBaseUrl)) {
  $PublicBaseUrl = $env:R2_PUBLIC_BASE_URL
}
if ([string]::IsNullOrWhiteSpace($ApiBaseUrl)) {
  $ApiBaseUrl = $env:UPDATE_API_BASE_URL
}
if ([string]::IsNullOrWhiteSpace($PublishToken)) {
  $PublishToken = $env:RELEASE_PUBLISH_TOKEN
}
if ([string]::IsNullOrWhiteSpace($Channel)) {
  $Channel = $env:RELEASE_CHANNEL
}
if ([string]::IsNullOrWhiteSpace($Channel)) {
  $Channel = "alpha"
}
if ([string]::IsNullOrWhiteSpace($SummaryEs)) {
  $SummaryEs = $ReleaseNotes
}
if ([string]::IsNullOrWhiteSpace($SummaryEn)) {
  $SummaryEn = $ReleaseNotes
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
if ([string]::IsNullOrWhiteSpace($ApiBaseUrl)) {
  throw "ApiBaseUrl missing. Set -ApiBaseUrl or env:UPDATE_API_BASE_URL"
}
if ([string]::IsNullOrWhiteSpace($PublishToken)) {
  throw "PublishToken missing. Set -PublishToken or env:RELEASE_PUBLISH_TOKEN"
}

if (-not $BuildAndroid -and -not $BuildWindows) {
  $BuildAndroid = $true
  $BuildWindows = $true
}

Assert-Command -CommandName "aws" -Hint "Install AWS CLI: winget install Amazon.AWSCLI"
Assert-Command -CommandName "flutter" -Hint "Install Flutter SDK and ensure flutter is in PATH"
Assert-Command -CommandName "Invoke-RestMethod" -Hint "Run this script in PowerShell 5+ or PowerShell 7+"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = Resolve-Path (Join-Path $scriptDir "..\..")
$appDir = Join-Path $repoRoot "apps\kumoriya_app"
$pubspecPath = Join-Path $appDir "pubspec.yaml"
$issPath = Join-Path $appDir "windows\kumoriya_installer.iss"

$version = Get-AppVersion -PubspecPath $pubspecPath
$tag = "v$version"

$apkOutputDir = Join-Path $appDir "build\app\outputs\flutter-apk"
$universalApkName = "app-release.apk"
$splitApkNames = @(
  "app-armeabi-v7a-release.apk",
  "app-arm64-v8a-release.apk",
  "app-x86_64-release.apk"
)
$setupFileName = "Kumoriya-$version-windows-x64-setup.exe"
$setupOutPath = Join-Path $appDir "build\windows\installer\$setupFileName"

Push-Location $appDir
try {
  if (-not $SkipBuild) {
    if ($BuildAndroid) {
      Write-Host "Building Android universal APK..."
      flutter build apk --release
      Write-Host "Building Android per-ABI APKs..."
      flutter build apk --release --split-per-abi --target-platform android-arm,android-arm64,android-x64
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

if ($BuildAndroid) {
  if (-not (Test-Path (Join-Path $apkOutputDir $universalApkName))) {
    throw "Universal APK not found at $(Join-Path $apkOutputDir $universalApkName)"
  }
  foreach ($name in $splitApkNames) {
    if (-not (Test-Path (Join-Path $apkOutputDir $name))) {
      throw "Split APK not found at $(Join-Path $apkOutputDir $name)"
    }
  }
}
if ($BuildWindows -and -not (Test-Path $setupOutPath)) {
  throw "Windows installer not found at $setupOutPath"
}

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

if (-not (Test-Path $releaseNotesEsPath)) {
  throw "Release notes ES file not found: $releaseNotesEsPath"
}
if (-not (Test-Path $releaseNotesEnPath)) {
  throw "Release notes EN file not found: $releaseNotesEnPath"
}

$notesEsMarkdown = Get-Content -Path $releaseNotesEsPath -Raw
$notesEnMarkdown = Get-Content -Path $releaseNotesEnPath -Raw

$windowsUrl = "$PublicBaseUrl/$windowsKey"

$releaseMeta = @{
  version = $version
  tag = $tag
  date = (Get-Date -Format "yyyy-MM-dd")
  channels = @($Channel)
  manifest_release_notes = $ReleaseNotes
  summary = @{
    es = $SummaryEs
    en = $SummaryEn
  }
  artifacts = @{}
  changelog_paths = @{
    es = "docs/releases/es/$tag.md"
    en = "docs/releases/en/$tag.md"
  }
  notes_markdown = @{
    es = $notesEsMarkdown
    en = $notesEnMarkdown
  }
}

# Build Android artifact metadata (used for upload, release.json, update.json and API publish).
$androidArtifacts = @()
if ($BuildAndroid) {
  # Tuple: source apk name -> @(abi_key, file_name).
  # abi_key uses underscores to match the Go backend enum (AndroidABI*).
  # file_name uses hyphens for human-friendly download names.
  $abiMap = @{
    "app-release.apk" = @("universal", "kumoriya-$version-universal.apk")
    "app-armeabi-v7a-release.apk" = @("armeabi_v7a", "kumoriya-$version-armeabi-v7a.apk")
    "app-arm64-v8a-release.apk" = @("arm64_v8a", "kumoriya-$version-arm64-v8a.apk")
    "app-x86_64-release.apk" = @("x86_64", "kumoriya-$version-x86_64.apk")
  }
  foreach ($source in $abiMap.Keys) {
    $abi = $abiMap[$source][0]
    $fileName = $abiMap[$source][1]
    $sourcePath = Join-Path $apkOutputDir $source
    $sha256 = (Get-FileHash -Algorithm SHA256 -Path $sourcePath).Hash.ToLower()
    $sizeBytes = (Get-Item $sourcePath).Length
    $key = "artifacts/android/$tag/$fileName"
    $url = "$PublicBaseUrl/$key"

    $androidArtifacts += [PSCustomObject]@{
      abi = $abi
      source_path = $sourcePath
      file_name = $fileName
      r2_key = $key
      public_url = $url
      sha256 = $sha256
      size_bytes = $sizeBytes
    }
  }

  # Legacy single-artifact entry for release.json (human reference)
  $universalArtifact = $androidArtifacts | Where-Object { $_.abi -eq "universal" } | Select-Object -First 1
  $releaseMeta.artifacts.android = @{
    file_name = $universalArtifact.file_name
    r2_key = $universalArtifact.r2_key
    public_url = $universalArtifact.public_url
    abis = @()
  }
  foreach ($a in $androidArtifacts) {
    $releaseMeta.artifacts.android.abis += @{
      abi = $a.abi
      file_name = $a.file_name
      r2_key = $a.r2_key
      public_url = $a.public_url
      size_bytes = $a.size_bytes
      sha256 = $a.sha256
    }
  }
}
if ($BuildWindows) {
  $releaseMeta.artifacts.windows = @{
    file_name = $setupFileName
    r2_key = $windowsKey
    public_url = $windowsUrl
  }
}
$releaseMeta | ConvertTo-Json -Depth 8 | Set-Content -Path $releaseJsonPath

$updateManifest = @{}
if ($BuildAndroid) {
  $universalArtifact = $androidArtifacts | Where-Object { $_.abi -eq "universal" } | Select-Object -First 1
  $updateManifest.android = @{
    latest_version = $version
    url = $universalArtifact.public_url
    release_notes = $ReleaseNotes
    universal = @{
      url = $universalArtifact.public_url
      file_name = $universalArtifact.file_name
      r2_key = $universalArtifact.r2_key
      size_bytes = $universalArtifact.size_bytes
      sha256 = $universalArtifact.sha256
    }
    abis = @{}
  }
  foreach ($a in $androidArtifacts) {
    if ($a.abi -eq "universal") { continue }
    $updateManifest.android.abis[$a.abi] = @{
      url = $a.public_url
      file_name = $a.file_name
      r2_key = $a.r2_key
      size_bytes = $a.size_bytes
      sha256 = $a.sha256
    }
  }
}
if ($BuildWindows) {
  $updateManifest.windows = @{
    latest_version = $version
    url = $windowsUrl
    release_notes = $ReleaseNotes
  }
}
$updateManifest | ConvertTo-Json -Depth 8 | Set-Content -Path $updateManifestPath

foreach ($a in $androidArtifacts) {
  Upload-FileToR2 `
    -FilePath $a.source_path `
    -Bucket $BucketName `
    -Key $a.r2_key `
    -Endpoint $EndpointUrl `
    -ContentType "application/vnd.android.package-archive" `
    -ContentDisposition "attachment; filename=`"$($a.file_name)`""
}

if ($BuildWindows) {
  Upload-FileToR2 -FilePath $setupOutPath -Bucket $BucketName -Key $windowsKey -Endpoint $EndpointUrl -ContentType "application/octet-stream" -ContentDisposition "attachment; filename=`"$(Split-Path $setupOutPath -Leaf)`""
}

Upload-FileToR2 -FilePath $releaseJsonPath -Bucket $BucketName -Key $releaseJsonKey -Endpoint $EndpointUrl -ContentType "application/json"

if (Test-Path $releaseNotesEsPath) {
  Upload-FileToR2 -FilePath $releaseNotesEsPath -Bucket $BucketName -Key $changelogEsKey -Endpoint $EndpointUrl
}

if (Test-Path $releaseNotesEnPath) {
  Upload-FileToR2 -FilePath $releaseNotesEnPath -Bucket $BucketName -Key $changelogEnKey -Endpoint $EndpointUrl
}

$publishBody = @{
  version = $version
  tag = $tag
  date = (Get-Date -Format "yyyy-MM-dd")
  channel = $Channel
  manifest_release_notes = $ReleaseNotes
  summary = @{
    es = $SummaryEs
    en = $SummaryEn
  }
  notes_markdown = @{
    es = $notesEsMarkdown
    en = $notesEnMarkdown
  }
  downloads = @{}
  is_latest = $true
}

if ($BuildAndroid) {
  $universalArtifact = $androidArtifacts | Where-Object { $_.abi -eq "universal" } | Select-Object -First 1
  $publishBody.downloads.android = @{
    url = $universalArtifact.public_url
    file_name = $universalArtifact.file_name
    r2_key = $universalArtifact.r2_key
    size_bytes = $universalArtifact.size_bytes
    sha256 = $universalArtifact.sha256
    universal = @{
      url = $universalArtifact.public_url
      file_name = $universalArtifact.file_name
      r2_key = $universalArtifact.r2_key
      size_bytes = $universalArtifact.size_bytes
      sha256 = $universalArtifact.sha256
    }
    abis = @{}
  }
  foreach ($a in $androidArtifacts) {
    if ($a.abi -eq "universal") { continue }
    $publishBody.downloads.android.abis[$a.abi] = @{
      url = $a.public_url
      file_name = $a.file_name
      r2_key = $a.r2_key
      size_bytes = $a.size_bytes
      sha256 = $a.sha256
    }
  }
}
if ($BuildWindows) {
  $publishBody.downloads.windows = @{
    url = $windowsUrl
    file_name = $setupFileName
    r2_key = $windowsKey
  }
}

$publishUrl = "$($ApiBaseUrl.TrimEnd('/'))/internal/releases/publish"
$headers = @{
  Authorization = "Bearer $PublishToken"
}

Write-Host "Publishing release metadata to API..."
Invoke-RestMethod `
  -Method Post `
  -Uri $publishUrl `
  -Headers $headers `
  -ContentType "application/json" `
  -Body ($publishBody | ConvertTo-Json -Depth 10)

Upload-FileToR2 -FilePath $updateManifestPath -Bucket $BucketName -Key "update.json" -Endpoint $EndpointUrl -ContentType "application/json"

Write-Host ""
Write-Host "Release published successfully."
Write-Host "Version: $version"
if ($BuildAndroid) {
  foreach ($a in $androidArtifacts) {
    Write-Host "Android $($a.abi) URL: $($a.public_url)"
  }
}
if ($BuildWindows) { Write-Host "Windows URL: $windowsUrl" }
Write-Host "API publish URL: $publishUrl"
Write-Host "Manifest URL: $PublicBaseUrl/update.json"
