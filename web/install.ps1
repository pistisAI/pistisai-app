# Pistisai web bootstrap installer — served from pistisai.app/install.ps1
$ErrorActionPreference = "Stop"
Write-Host "Pistisai Windows Installer"
$version = "1.0.3"
$INSTALL_VERSION = "1.0.3"
try {
    $latest = Invoke-RestMethod "https://api.github.com/repos/pistisAI/pistisai-app/releases/latest"
    $version = $latest.tag_name.TrimStart('v')
} catch {
    Write-Host "Using bundled version $version"
}
$release = Invoke-RestMethod "https://api.github.com/repos/pistisAI/pistisai-app/releases/tags/v$version"
$asset = $release.assets | Where-Object { $_.name -eq "Pistisai-Windows-x64-Setup.exe" } | Select-Object -First 1
if (-not $asset) { throw "Pistisai-Windows-x64-Setup.exe not found on release v$version" }
$dest = Join-Path $env:LOCALAPPDATA "Pistisai\cache\Pistisai-Windows-x64-Setup-$version.exe"
New-Item -ItemType Directory -Force -Path (Split-Path $dest) | Out-Null
Write-Host "Downloading Pistisai v$version..."
Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $dest
Write-Host "Launching installer..."
Start-Process -FilePath $dest -Wait
Write-Host "Done." -ForegroundColor Green
