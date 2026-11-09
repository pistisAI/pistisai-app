# CI/CD Quick Reference

Release automation starts with a push to `main`. [Auto Version Bump](../../../.github/workflows/auto-version-bump.yml) is the entry point. It ignores pushes that already change `assets/version.json`. A commit message containing `[major]` or `[minor]` selects the bump level. Anything else is a patch bump.

```text
push to main
  -> Auto Version Bump
    -> Web Deploy
      -> Desktop Build, Mobile Build, Backend Deploy
```

Web Deploy must complete successfully before the three downstream workflows proceed. Each of them also accepts `workflow_dispatch`. Desktop Build additionally runs on tags matching `v*`.

| Workflow | File | What it ships |
| --- | --- | --- |
| Auto Version Bump | `.github/workflows/auto-version-bump.yml` | `assets/version.json` and `pubspec.yaml` |
| Web Deploy | `.github/workflows/deploy-web.yml` | `ghcr.io/pistisai/pistisai-app-web` via Coolify |
| Desktop Build | `.github/workflows/build-desktop.yml` | Linux, Windows, and macOS artifacts |
| Mobile Build | `.github/workflows/build-mobile.yml` | Android APKs. iOS only when dispatched and the `ios/` project exists |
| Backend Deploy | `.github/workflows/deploy-backend.yml` | Backend containers |

Flutter CI pins the exact version in root `pubspec.yaml` `environment.flutter` (currently `3.47.7`, stable). Web and Android runners are `ubuntu-24.04`.

There is no `deployment.yml` or `build-pipeline.yml` in `.github/workflows/`. [Unified Deployment Workflow](UNIFIED_DEPLOYMENT_WORKFLOW.md) describes that older pipeline and is not the current path.

## Commands

```bash
# Rebuild and deploy the web image without waiting for a version bump
gh workflow run "🌐 Web Deploy" --ref main

# Android APKs only (the default)
gh workflow run "📱 Mobile Build & Release" --ref main

# Follow the latest web deploy
gh run list --workflow="deploy-web.yml" --limit 3
```

## Where to read next

- [Web Deploy](WEB_DEPLOY.md) — image, nginx cache, Coolify, Traefik health
- [Android Build Guide](../../development/ANDROID_BUILD_GUIDE.md) — SDK 37, signing secrets, APK job
