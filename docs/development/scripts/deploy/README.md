# Pistisai Deployment Scripts

> **Verified against code (2026-11-24):** there is no `scripts/archive/` directory, no root `k8s/` directory, and no `kubectl` usage in `.github/workflows/`. The Kubernetes/"archived VPS" description that used to be here was stale. See `docs/deployment/` for the current deployment guides.

## Current deployment path

Image builds and publishes run **only through GitHub Actions**:

- `.github/workflows/deploy-web.yml` — builds/publishes the web image to GHCR, then `deploy_dokploy` asks Dokploy to pull it, then a full-zone Cloudflare cache purge runs. The desktop app is the hub. Hosted web is a Dokploy Application (`ghcr.io/pistisai/pistisai-app-web`, port 80).
- `.github/workflows/deploy-backend.yml` — builds/publishes the api-backend, streaming-proxy, and postgres images, then its `deploy_dokploy` job asks Dokploy to pull the Compose file `config/docker/docker-compose.dokploy-backend.yml`.

`scripts/ci/trigger_dokploy_deploy.sh` and those jobs land with [#1056](https://github.com/pistisAI/pistisai-app/issues/1056). See [Dokploy](../../../deployment/DOKPLOY.md). Kubernetes manifests under `config/kubernetes/base/` and `services/*/k8s/` are legacy and unmaintained. There is no root `k8s/` directory. `scripts/deploy-hermes-pistisai-vps.sh` has been removed. Deploys are not run over SSH.

## Local / development

Use the compose files in the repository root (`docker-compose.yml`, `docker-compose.multi.yml`) and `config/docker/`. Validate the local environment with `scripts/docker/validate_dev_environment.sh`.

## Scripts that still exist

- `scripts/powershell/Deploy-Pistisai.ps1` — present (not archived).
- `scripts/powershell/BuildEnvironmentUtilities.ps1` — present.
- `scripts/version_manager.sh` — present; version bumps are also automated by `.github/workflows/auto-version-bump.yml` and `scripts/version_bump_kind.py`.

Scripts such as `sync_versions.sh` and `verify_deployment.sh` are not present; their versioning/verification roles are handled by CI, not by shell scripts in this repo.
