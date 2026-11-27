# Pistisai GitHub Release Asset Upload Script
# Uploads built assets to an existing GitHub release

[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '')]
[CmdletBinding(DefaultParameterSetName = 'Upload')]
param(
    [Parameter(Mandatory = $true, ParameterSetName = 'Upload')]
    [string]$ReleaseId,

    [Parameter(Mandatory = $false, ParameterSetName = 'Upload')]
    [string]$AssetPath,

    [Parameter(ParameterSetName = 'Upload')]
    [switch]$Help,

    [string]$RepoOwner,

    [string]$RepoName,

    [Parameter(Mandatory = $true, ParameterSetName = 'Print')]
    [switch]$PrintRepository
)

# Upstream repository. A rebrand overrides -RepoOwner/-RepoName or
# PISTISAI_GITHUB_OWNER / PISTISAI_GITHUB_REPO, or sets BRAND so
# repository_label in brand/<id>/brand.yaml supplies owner/repo.
# See docs/WHITE_LABEL.md.
function Resolve-PistisaiGitHubRepository {
    param(
        [string]$Owner,
        [string]$Name
    )

    if (-not $Owner) { $Owner = $env:PISTISAI_GITHUB_OWNER }
    if (-not $Name) { $Name = $env:PISTISAI_GITHUB_REPO }

    $slug = '^[A-Za-z0-9_.-]+$'
    if ((-not $Owner) -or (-not $Name)) {
        $brandId = if ($env:BRAND) { $env:BRAND } else { 'pistisai' }
        if ($brandId -match '^[A-Za-z0-9_-]+$') {
            $brandFile = Join-Path $PSScriptRoot "..\..\brand\$brandId\brand.yaml"
            if (Test-Path -LiteralPath $brandFile) {
                $match = Select-String -LiteralPath $brandFile -Pattern '^repository_label:\s*[''"]?([A-Za-z0-9_.-]+)/([A-Za-z0-9_.-]+)' | Select-Object -First 1
                if ($match) {
                    if (-not $Owner) { $Owner = $match.Matches[0].Groups[1].Value }
                    if (-not $Name) { $Name = $match.Matches[0].Groups[2].Value }
                }
            }
        }
    }

    if (-not $Owner -or $Owner -notmatch $slug) { $Owner = 'pistisAI' }
    if (-not $Name -or $Name -notmatch $slug) { $Name = 'pistisai-app' }

    return [pscustomobject]@{
        Owner = $Owner
        Name  = $Name
    }
}

# Import build environment utilities
$utilsPath = Join-Path $PSScriptRoot "BuildEnvironmentUtilities.ps1"
if (Test-Path $utilsPath) {
    . $utilsPath
} else {
    Write-Host "BuildEnvironmentUtilities module not found, using basic functions" -ForegroundColor Yellow

    # Basic logging functions if utilities not available
    function Write-LogInfo { param($Message) Write-Host "[INFO] $Message" -ForegroundColor Cyan }
    function Write-LogSuccess { param($Message) Write-Host "[SUCCESS] $Message" -ForegroundColor Green }
    function Write-LogError { param($Message) Write-Host "[ERROR] $Message" -ForegroundColor Red }
    function Write-LogWarning { param($Message) Write-Host "[WARNING] $Message" -ForegroundColor Yellow }
    function Get-ProjectRoot { return (Get-Location).Path }
}

# Configuration
$ProjectRoot = Get-ProjectRoot
$DistDir = Join-Path $ProjectRoot "dist\windows"

# Get version from version manager
$versionManagerPath = Join-Path $PSScriptRoot "version_manager.ps1"
if (Test-Path $versionManagerPath) {
    $Version = & $versionManagerPath get-semantic
} else {
    Write-LogError "Version manager not found"
    exit 1
}

function Show-Help {
    Write-Host "Pistisai GitHub Release Asset Upload Script" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Usage: .\Upload-GitHubReleaseAssets.ps1 -ReleaseId <id> [-AssetPath <path>]" -ForegroundColor White
    Write-Host ""
    Write-Host "Parameters:" -ForegroundColor Yellow
    Write-Host "  -ReleaseId <id>     GitHub release ID (required to upload)"
    Write-Host "  -AssetPath <path>   Specific asset file to upload (optional)"
    Write-Host "  -RepoOwner <owner>  GitHub owner (optional; overrides the environment)"
    Write-Host "  -RepoName <repo>    GitHub repository (optional; overrides the environment)"
    Write-Host "  -PrintRepository    Print owner/repo and exit"
    Write-Host "  -Help               Show this help message"
    Write-Host ""
    Write-Host "Environment: PISTISAI_GITHUB_OWNER, PISTISAI_GITHUB_REPO, BRAND" -ForegroundColor Yellow
    Write-Host "Default repository: pistisAI/pistisai-app" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Examples:" -ForegroundColor Green
    Write-Host "  .\Upload-GitHubReleaseAssets.ps1 -ReleaseId 228513276"
    Write-Host "  .\Upload-GitHubReleaseAssets.ps1 -ReleaseId 228513276 -AssetPath 'dist\windows\pistisai-3.7.0-portable.zip'"
}

function Send-AssetToGitHub {
    param(
        [string]$FilePath,
        [string]$ReleaseId,
        [int]$MaxRetries = 3
    )

    if (-not (Test-Path $FilePath)) {
        Write-LogError "Asset file not found: $FilePath"
        return $false
    }

    $fileName = Split-Path $FilePath -Leaf
    $fileSize = (Get-Item $FilePath).Length

    Write-LogInfo "Uploading $fileName ($fileSize bytes) to release $ReleaseId..."

    for ($attempt = 1; $attempt -le $MaxRetries; $attempt++) {
        try {
            if ($attempt -gt 1) {
                Write-LogInfo "Retry attempt $attempt of $MaxRetries for $fileName"
                Start-Sleep -Seconds (2 * $attempt)  # Exponential backoff
            }

            # GitHub CLI approach (requires gh CLI to be installed and authenticated)
            Write-LogInfo "Executing: gh release upload v$Version `"$FilePath`" --repo $script:GithubRepository --clobber"

            $result = & gh release upload "v$Version" $FilePath --repo $script:GithubRepository --clobber 2>&1

            if ($LASTEXITCODE -eq 0) {
                Write-LogSuccess "Successfully uploaded $fileName (attempt $attempt)"
                return $true
            } else {
                Write-LogWarning "Upload attempt $attempt failed for $fileName. Exit code: $LASTEXITCODE"
                if ($result) {
                    Write-LogWarning "Output: $result"
                }

                if ($attempt -eq $MaxRetries) {
                    Write-LogError "Failed to upload $fileName after $MaxRetries attempts"
                    return $false
                }
            }
        }
        catch {
            Write-LogWarning "Exception on attempt $attempt for $fileName`: $($_.Exception.Message)"

            if ($attempt -eq $MaxRetries) {
                Write-LogError "Failed to upload $fileName after $MaxRetries attempts due to exceptions"
                return $false
            }
        }
    }

    return $false
}

function Test-AssetUpload {
    param(
        [string]$FileName,
        [string]$ReleaseId
    )

    try {
        Write-LogInfo "Verifying upload of $FileName..."
        $assets = gh api "repos/$script:GithubRepository/releases/$ReleaseId/assets" | ConvertFrom-Json

        $asset = $assets | Where-Object { $_.name -eq $FileName }

        if ($asset -and $asset.state -eq "uploaded") {
            Write-LogSuccess "Verified: $FileName is uploaded and available"
            return $true
        } else {
            Write-LogError "Verification failed: $FileName not found or not in uploaded state"
            return $false
        }
    }
    catch {
        Write-LogWarning "Could not verify upload of $FileName`: $($_.Exception.Message)"
        return $false
    }
}

function Main {
    if ($PrintRepository) {
        Write-Output $script:GithubRepository
        return
    }

    Write-LogInfo "Pistisai GitHub Release Asset Upload v$Version"
    Write-LogInfo "Target repository: $script:GithubRepository"
    Write-LogInfo "================================================"

    if ($Help) {
        Show-Help
        return
    }

    if (-not $ReleaseId) {
        Write-LogError "ReleaseId parameter is required"
        Show-Help
        exit 1
    }

    # Check if GitHub CLI is available
    try {
        $ghVersion = gh --version
        Write-LogInfo "GitHub CLI detected: $($ghVersion[0])"
    }
    catch {
        Write-LogError "GitHub CLI (gh) is not installed or not in PATH"
        Write-LogError "Please install GitHub CLI from https://cli.github.com/"
        exit 1
    }

    $uploadedCount = 0
    $failedCount = 0

    if ($AssetPath) {
        # Upload specific asset
        if (Send-AssetToGitHub -FilePath $AssetPath -ReleaseId $ReleaseId) {
            $uploadedCount++
        } else {
            $failedCount++
        }
    } else {
        # Upload all v3.7.0 assets
        $assetPattern = "pistisai-$Version-portable.*"
        $assets = Get-ChildItem -Path $DistDir -Filter $assetPattern

        if ($assets.Count -eq 0) {
            Write-LogError "No assets found matching pattern: $assetPattern"
            exit 1
        }

        Write-LogInfo "Found $($assets.Count) assets to upload"

        foreach ($asset in $assets) {
            if (Send-AssetToGitHub -FilePath $asset.FullName -ReleaseId $ReleaseId) {
                # Verify the upload was successful
                if (Test-AssetUpload -FileName $asset.Name -ReleaseId $ReleaseId) {
                    $uploadedCount++
                } else {
                    Write-LogWarning "Upload reported success but verification failed for $($asset.Name)"
                    $failedCount++
                }
            } else {
                $failedCount++
            }
        }
    }

    Write-LogInfo "Upload Summary:"
    Write-LogInfo "  Uploaded: $uploadedCount"
    Write-LogInfo "  Failed: $failedCount"

    if ($failedCount -eq 0) {
        Write-LogSuccess "All assets uploaded successfully!"
    } else {
        Write-LogWarning "Some assets failed to upload"
        exit 1
    }
}

$resolvedRepository = Resolve-PistisaiGitHubRepository -Owner $RepoOwner -Name $RepoName
$script:GithubRepository = "$($resolvedRepository.Owner)/$($resolvedRepository.Name)"

# Execute main function when run, not when dot-sourced.
if ($MyInvocation.InvocationName -ne '.') {
    Main
}
