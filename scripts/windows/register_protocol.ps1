<#
.SYNOPSIS
    Registers the kumoriya:// URI protocol on Windows for development/debug.

.DESCRIPTION
    Creates per-user registry entries under HKCU\SOFTWARE\Classes\kumoriya so
    that Windows routes kumoriya:// URIs to the debug (or release) executable.
    Run this once per machine before testing deep links in debug mode.

    Must be run from the repo root or with -ExePath pointing to the built exe.

.PARAMETER ExePath
    Full path to kumoriya_app.exe. Defaults to the debug build output.

.EXAMPLE
    .\register_protocol.ps1
    .\register_protocol.ps1 -ExePath "C:\path\to\kumoriya_app.exe"
#>
param(
    [string]$ExePath = ""
)

$ErrorActionPreference = "Stop"

# Resolve exe path: default to the Flutter debug build output.
if ([string]::IsNullOrWhiteSpace($ExePath)) {
    $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
    $repoRoot  = Resolve-Path (Join-Path $scriptDir "..\..")
    $ExePath   = Join-Path $repoRoot "apps\kumoriya_app\build\windows\x64\runner\Debug\kumoriya_app.exe"
}

if (-not (Test-Path $ExePath)) {
    Write-Error "Executable not found: $ExePath"
    Write-Host "Build the app first with:  flutter build windows --debug"
    exit 1
}

$ExePath = (Resolve-Path $ExePath).Path
$scheme  = "kumoriya"
$regBase = "HKCU:\SOFTWARE\Classes\$scheme"

Write-Host "Registering protocol '${scheme}://' -> $ExePath" -ForegroundColor Cyan

# Create the protocol key and mark it as a URL scheme.
New-Item -Path $regBase -Force | Out-Null
Set-ItemProperty -Path $regBase -Name "(Default)"     -Value "URL:Kumoriya Protocol"
Set-ItemProperty -Path $regBase -Name "URL Protocol"  -Value ""

# shell\open\command tells Windows which exe to launch with the URI as %1.
$commandKey = "$regBase\shell\open\command"
New-Item -Path $commandKey -Force | Out-Null
Set-ItemProperty -Path $commandKey -Name "(Default)" -Value "`"$ExePath`" `"%1`""

Write-Host ""
Write-Host "Done. The following registry keys were created:" -ForegroundColor Green
Write-Host "  ${regBase}"
Write-Host "  ${regBase}\shell\open\command"
Write-Host ""
Write-Host "Test it by running:" -ForegroundColor Yellow
Write-Host "  Start-Process 'kumoriya://auth/callback?test=1'"
Write-Host ""
Write-Host "To unregister, run: .\unregister_protocol.ps1"
