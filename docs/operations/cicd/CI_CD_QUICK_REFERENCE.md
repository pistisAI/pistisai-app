# CI/CD Quick Reference

Release automation starts with a push to `main`. [Web Deploy](../../../.github/workflows/deploy-web.yml) is the deploy-chain entry point (see [Deploy trigger chain](DEPLOY_TRIGGER_CHAIN.md)). [Auto Version Bump](../../../.github/workflows/auto-version-bump.yml) still runs on that push and opens a version-bump PR; it does not gate deploys.

```text
push to main
  -> Web Deploy
    -> Desktop Build, Mobile Build, Backend Deploy
  -> Auto Version Bump (opens version PR; merge re-triggers Web Deploy)
```

Web Deploy must complete successfully before the three downstream workflows proceed. Each of them also accepts `workflow_dispatch`. Desktop Build additionally runs on tags matching `v*`.

| Workflow | File | What it ships |
| --- | --- | --- |
| Auto Version Bump | `.github/workflows/auto-version-bump.yml` | `assets/version.json` and `pubspec.yaml` |
| Web Deploy | `.github/workflows/deploy-web.yml` | `ghcr.io/pistisai/pistisai-app-web` via Docker Compose |
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

- [Web Deploy](WEB_DEPLOY.md) — image, nginx cache, Docker Compose health
- [Android Build Guide](../../development/ANDROID_BUILD_GUIDE.md) — SDK 37, signing secrets, APK job
