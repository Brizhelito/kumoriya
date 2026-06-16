<#
.SYNOPSIS
    Removes the kumoriya:// URI protocol registration from the current user's registry.

.EXAMPLE
    .\unregister_protocol.ps1
#>
$ErrorActionPreference = "Stop"

$scheme  = "kumoriya"
$regBase = "HKCU:\SOFTWARE\Classes\$scheme"

if (Test-Path $regBase) {
    Remove-Item -Path $regBase -Recurse -Force
    Write-Host "Removed protocol registration for '${scheme}://'." -ForegroundColor Green
} else {
    Write-Host "No registration found for '${scheme}://'. Nothing to do." -ForegroundColor Yellow
}
