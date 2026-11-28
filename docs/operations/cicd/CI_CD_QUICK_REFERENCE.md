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
| Web Deploy | `.github/workflows/deploy-web.yml` | `ghcr.io/pistisai/pistisai-app-web`, then Dokploy pulls it (`deploy_dokploy`, [#1056](https://github.com/pistisAI/pistisai-app/issues/1056)) |
| Desktop Build | `.github/workflows/build-desktop.yml` | Linux, Windows, and macOS artifacts. The desktop app is the hub. |
| Mobile Build | `.github/workflows/build-mobile.yml` | Android APKs. iOS only when dispatched and the `ios/` project exists |
| Backend Deploy | `.github/workflows/deploy-backend.yml` | `api-backend` and `streaming-proxy` images, then Dokploy pulls them |

Flutter CI pins the exact version in root `pubspec.yaml` `environment.flutter` (currently `3.47.9`, stable). Web and Android runners are `ubuntu-24.04`.

There is no `deployment.yml` or `build-pipeline.yml` in `.github/workflows/`. [Unified Deployment Workflow](../../archive/historical-reports/operations/cicd/UNIFIED_DEPLOYMENT_WORKFLOW.md) describes that older pipeline and is not the current path.

Hosted web and API run on Dokploy. `deploy-web.yml` and `deploy-backend.yml` each have a `deploy_dokploy` job that calls `scripts/ci/trigger_dokploy_deploy.sh` (#1056). Secrets: `DOKPLOY_WEBHOOK_URL`, `DOKPLOY_BACKEND_WEBHOOK_URL`. Optional: `DOKPLOY_API_URL`, `DOKPLOY_API_KEY`, `DOKPLOY_WEB_APPLICATION_ID`, `DOKPLOY_BACKEND_COMPOSE_ID`. Repository variable `DOKPLOY_REQUIRED=true` fails the job when the webhook is missing. Setup: [Dokploy](../../deployment/DOKPLOY.md). Kubernetes and k3s are legacy and unmaintained.

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

- [Web Deploy](WEB_DEPLOY.md) — image, nginx cache, Dokploy Application
- [Dokploy](../../deployment/DOKPLOY.md) — hosted path, secrets, rollback
- [Android Build Guide](../../development/ANDROID_BUILD_GUIDE.md) — SDK 37, signing secrets, APK job
