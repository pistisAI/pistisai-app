# Pistisai Windows Installer
# Downloads and runs the latest GitHub release Setup.exe
param(
    [string]$Version = "",
    [switch]$Silent
)

$ErrorActionPreference = "Stop"
$INSTALL_VERSION = ""

function Write-Info([string]$Message) {
    Write-Host $Message
}

function Write-Success([string]$Message) {
    Write-Host $Message -ForegroundColor Green
}

function Get-LatestVersion {
    $response = Invoke-RestMethod -Uri "https://api.github.com/repos/pistisAI/pistisai-app/releases/latest"
    return ($response.tag_name -replace '^v', '')
}

function Get-SetupAssetUrl([string]$ReleaseVersion) {
    $response = Invoke-RestMethod -Uri "https://api.github.com/repos/pistisAI/pistisai-app/releases/tags/v$ReleaseVersion"
    $asset = $response.assets | Where-Object { $_.name -eq "Pistisai-Windows-x64-Setup.exe" } | Select-Object -First 1
    if (-not $asset) {
        throw "Pistisai-Windows-x64-Setup.exe not found on release v$ReleaseVersion"
    }
    return $asset.browser_download_url
}

Write-Info "Pistisai Windows Installer"

if ([string]::IsNullOrWhiteSpace($Version)) {
    if (-not [string]::IsNullOrWhiteSpace($INSTALL_VERSION)) {
        $Version = $INSTALL_VERSION
    } else {
        $Version = Get-LatestVersion
    }
}

$cacheDir = Join-Path $env:LOCALAPPDATA "Pistisai\cache"
New-Item -ItemType Directory -Force -Path $cacheDir | Out-Null

$installerPath = Join-Path $cacheDir "Pistisai-Windows-x64-Setup-$Version.exe"
$downloadUrl = Get-SetupAssetUrl -ReleaseVersion $Version

Write-Info "Downloading Pistisai v$Version..."
Invoke-WebRequest -Uri $downloadUrl -OutFile $installerPath

Write-Info "Launching installer..."
$installerArgs = @()
if ($Silent) {
    $installerArgs += @("/VERYSILENT", "/NORESTART")
}

Start-Process -FilePath $installerPath -ArgumentList $installerArgs -Wait
Write-Success "Pistisai v$Version installer finished."
