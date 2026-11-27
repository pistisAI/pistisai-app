# Pistisai Release Workflow

## Overview

This document provides the complete, tested workflow for creating Pistisai releases. Follow these steps exactly to ensure successful releases with all assets properly uploaded.

> **Verified against code / policy (2026-11-24):** image builds and publishes run **only** through GitHub Actions (`.github/workflows/deploy-web.yml`, `.github/workflows/deploy-backend.yml`). `deploy-web.yml:106-131` runs a full-zone Cloudflare cache purge after the image push; `deploy-backend.yml:27-160` only builds and publishes images (no purge job). The host-side `docker compose up -d` is still a manual step (see the "Known gap" comment at `deploy-web.yml:103-105`). There is no manual VPS/SSH deploy step. The old VPS sections below are retained as historical reference and are labelled as such.

## Prerequisites

### Required Tools

- [x] **PowerShell 5.1+** (Windows) or **PowerShell Core 7+** (cross-platform)
- [x] **Flutter SDK** (latest stable version)
- [x] **Git** with repository access
- [x] **GitHub CLI** (`gh`) installed and authenticated
- [x] **GitHub Actions** deploy workflows available (no manual VPS/SSH access is used)

### Authentication Setup

```bash
# Authenticate GitHub CLI (one-time setup)
gh auth login

# Verify authentication
gh auth status
```

### Environment Verification

```powershell
# Run this before starting any release
.\scripts\powershell\version_manager.ps1 get
flutter doctor
gh auth status
git status
```

## Release Workflow Steps

### Step 1: Pre-Release Preparation

1. **Ensure Clean Working Directory**:

   ```bash
   git status
   # Should show "working tree clean"
   ```

2. **Verify Current Version**:

   ```powershell
   .\scripts\powershell\version_manager.ps1 get
   ```

3. **Test Build Locally**:

   ```powershell
   .\scripts\powershell\Build-GitHubReleaseAssets.ps1 -Clean
   ```

### Step 2: Version Management

1. **Update Version Number**:

   ```powershell
   # For new major/minor release
   .\scripts\powershell\version_manager.ps1 set X.Y.Z
   
   # Example for v1.5.60
   .\scripts\powershell\version_manager.ps1 set 1.5.60
   ```

2. **Verify Version Update**:

   ```powershell
   .\scripts\powershell\version_manager.ps1 get
   # Check that all files are updated consistently
   ```

### Step 3: Build Release Assets

1. **Clean Build with Asset Creation**:

   ```powershell
   .\scripts\powershell\Build-GitHubReleaseAssets.ps1 -Clean
   ```

2. **Verify Build Output**:

   ```powershell
   Get-ChildItem dist\windows\Pistisai-*.zip*
   # Should show both .zip and .sha256 files
   ```

### Step 4: Create GitHub Release

1. **Create Release via GitHub CLI**:

   ```bash
   # Create draft release
   gh release create v1.5.60 --draft --title "Pistisai v1.5.60 - [Feature Name]" --notes-file release-notes.md
   
   # Or create release directly
   gh release create v1.5.60 --title "Pistisai v1.5.60 - [Feature Name]" --notes "Release notes here"
   ```

2. **Get Release ID** (if using API):

   ```bash
   gh api repos/Pistisai/pistisai-app/releases/latest | jq '.id'
   ```

### Step 5: Upload Assets to GitHub Release

**Option A: Integrated Build + Upload (Recommended)**

```powershell
# Build and upload in one step
.\scripts\powershell\Build-GitHubReleaseAssets.ps1 -Clean -UploadToGitHub -ReleaseId <release-id>
```

**Option B: Separate Upload**

```powershell
# Upload to existing release
.\scripts\powershell\Upload-GitHubReleaseAssets.ps1 -ReleaseId <release-id>
```

**Option C: GitHub CLI Upload**

```bash
# Upload specific files
gh release upload v1.5.60 dist/windows/Pistisai-1.5.60-portable.zip
gh release upload v1.5.60 dist/windows/Pistisai-1.5.60-portable.zip.sha256
```

### Step 6: Commit and Push Changes

1. **Commit Version Changes**:

   ```bash
   git add .
   git commit -m "Release v1.5.60: [Brief description of main features]
   
   - [Feature 1 description]
   - [Feature 2 description]
   - Update version to 1.5.60+182"
   ```

2. **Push to Repository**:

   ```bash
   git push origin main
   ```

### Step 7: Deploy via GitHub Actions (not manual VPS)

> **Verified against code / policy:** image builds and publishes run only through `.github/workflows/deploy-web.yml` and `.github/workflows/deploy-backend.yml`, triggered from `main`. No SSH/VPS step exists or is permitted; the manual VPS instructions that followed this heading were removed.

1. **Push the release commit to `main`** (Step 6) — the image-build workflows run automatically; `deploy-web.yml` purges the full Cloudflare zone after publishing, and the host must still pull the new image (`docker compose up -d`).

2. **Verify the deployment** from the Actions run and the public version endpoint:

   ```bash
   gh run list --workflow=deploy-web.yml --limit 3
   curl -s https://app.example.com/version.json
   # Should show the new version number
   ```

### Step 8: Post-Release Verification

1. **Verify GitHub Release**:
   - [ ] Release page accessible
   - [ ] Assets downloadable
   - [ ] Release notes complete
   - [ ] Version tags correct

2. **Verify GitHub Actions Deployment**:
   - [ ] `deploy-web.yml` / `deploy-backend.yml` image builds succeeded (`deploy-web.yml` also completed its full-zone Cloudflare cache purge)
   - [ ] Application accessible at example.com
   - [ ] Version number updated
   - [ ] New features functional

3. **Test Download and Installation**:
   - [ ] Download ZIP package
   - [ ] Verify SHA256 checksum
   - [ ] Test application startup
   - [ ] Verify new features work

## Error Handling

### Common Issues and Solutions

#### GitHub CLI Not Authenticated

```bash
# Error: authentication required
gh auth login
gh auth refresh
```

#### Asset Upload Fails

```powershell
# Retry with standalone upload script
.\scripts\powershell\Upload-GitHubReleaseAssets.ps1 -ReleaseId <id>
```

#### Build Fails

```powershell
# Clean everything and retry
flutter clean
flutter pub get
.\scripts\powershell\Build-GitHubReleaseAssets.ps1 -Clean
```

#### GitHub Actions Deployment Fails

```bash
# Inspect the failing run and its logs (deploys are Actions-only)
gh run list --workflow=deploy-web.yml --limit 5
gh run view <run-id> --log-failed
# Fix the cause on main and let the workflow re-run; never deploy manually over SSH
```

### Rollback Procedures

#### Rollback GitHub Release

```bash
# Delete release if needed
gh release delete v1.5.60 --yes

# Or mark as pre-release
gh release edit v1.5.60 --prerelease
```

#### Rollback Deployment

```bash
# Revert the release commit on main via a normal PR (never force-push main)
# The deploy workflows then run against the reverted main automatically.
gh run list --workflow=deploy-web.yml --limit 5
```

## Quality Checklist

### Pre-Release Checklist

- [ ] All tests passing
- [ ] Documentation updated
- [ ] Version numbers consistent
- [ ] Build artifacts verified
- [ ] GitHub CLI authenticated

### Release Checklist

- [ ] GitHub release created
- [ ] Assets uploaded successfully
- [ ] Release notes comprehensive
- [ ] Version committed and pushed
- [ ] GitHub Actions deployment successful

### Post-Release Checklist

- [ ] Download links functional
- [ ] Application starts correctly
- [ ] New features working
- [ ] Version displayed correctly
- [ ] No critical issues reported

## Automation Opportunities

### Future Improvements

1. **GitHub Actions Workflow**: Automate entire release process
2. **Automated Testing**: Run tests before release creation
3. **Multi-Platform Builds**: Automate Linux package creation
4. **Release Notes Generation**: Auto-generate from commit messages
5. **Deployment Verification**: Automated post-deployment testing

### Monitoring

- Set up alerts for failed deployments
- Monitor download statistics
- Track user feedback on new releases
- Monitor application performance post-release

## Contact and Support

For questions about the release process:

- Check this documentation first
- Review post-mortem documents for known issues
- Create GitHub issue for process improvements
- Update this documentation when process changes
