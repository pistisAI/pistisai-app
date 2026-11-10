# {{product_name}} web bootstrap installer — served from {{website_domain}}/install.ps1
$ErrorActionPreference = "Stop"
Write-Host "{{product_name}} Windows Installer"
$version = "1.0.3"
$INSTALL_VERSION = "1.0.3"
try {
    $latest = Invoke-RestMethod "https://api.github.com/repos/{{github_repo}}/releases/latest"
    $version = $latest.tag_name.TrimStart('v')
} catch {
    Write-Host "Using bundled version $version"
}
$release = Invoke-RestMethod "https://api.github.com/repos/{{github_repo}}/releases/tags/v$version"
$asset = $release.assets | Where-Object { $_.name -eq "{{artifact_prefix}}-Windows-x64-Setup.exe" } | Select-Object -First 1
if (-not $asset) { throw "{{artifact_prefix}}-Windows-x64-Setup.exe not found on release v$version" }
$dest = Join-Path $env:LOCALAPPDATA "{{product_name}}\cache\{{artifact_prefix}}-Windows-x64-Setup-$version.exe"
New-Item -ItemType Directory -Force -Path (Split-Path $dest) | Out-Null
Write-Host "Downloading {{product_name}} v$version..."
Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $dest
Write-Host "Launching installer..."
Start-Process -FilePath $dest -Wait
Write-Host "Done." -ForegroundColor Green
