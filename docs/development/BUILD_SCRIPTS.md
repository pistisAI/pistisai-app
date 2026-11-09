# IAClé Build Scripts Guide

## Overview

Windows/Linux packaging helpers live under `scripts/packaging/` and
`scripts/powershell/`. Prefer CI desktop/release workflows for shipping
artifacts; use these scripts for local packaging experiments.

## Current scripts (verified in-repo)

### Windows packaging

```powershell
# Installer (Inno Setup; also see windows/installer/IAClé.iss)
.\scripts\packaging\build_windows_installer.ps1

# Portable ZIP
.\scripts\packaging\build_windows_portable.ps1

# Broader GitHub release-asset helper
.\scripts\powershell\Build-GitHubReleaseAssets.ps1
```

### Version helper

```powershell
.\scripts\powershell\version_manager.ps1
```

Keep `assets/version.json` and `pubspec.yaml` in sync (see [AGENTS.md](../../AGENTS.md)).

### Linux packaging

```bash
./scripts/packaging/build_appimage.sh
./scripts/packaging/build_all_packages.sh
# build_deb.sh still exists; product messaging prefers AppImage — confirm before shipping .deb
```

### Web

```bash
flutter build web --release --no-web-resources-cdn
docker build -f config/docker/Dockerfile.web -t IAClé-web .
```

## Removed / missing names (do not document as live)

These paths are **not** in the repository:

- `Build-GitHubReleaseAssets-Simple.ps1` (root or scripts)
- `Create-UnifiedPackages.ps1`
- root-level `version_manager.ps1`
- `scripts/deploy/deploy_web.sh`
- `scripts/packaging/build_macos_app.sh` / `build_macos_dmg.sh`

Use Flutter/`build-desktop` CI for macOS until dedicated packaging scripts land.

## Package format status

| Format | Status | Notes |
|--------|--------|-------|
| Portable ZIP | Available | `scripts/packaging/build_windows_portable.ps1` |
| Inno Setup installer | Available | `windows/installer/IAClé.iss` + packaging script / CI |
| AppImage | Available | `scripts/packaging/build_appimage.sh` |
| `.deb` | Script present | Confirm product support before documenting as primary |
| MSI / NSIS | Not implemented | Historical placeholders only |

## Troubleshooting

- **GitHub upload fails**: install/auth GitHub CLI (`gh auth login`).
- **Build fails**: run `flutter doctor`; also `cd lib/shared && flutter pub get`.
- **Wrong script name**: inventory `scripts/packaging/` and `scripts/powershell/` instead of older root-level names.
