# Pistisai Deployment Scripts

> **Verified against code (2026-11-24):** there is no `scripts/archive/` directory, no root `k8s/` directory, and no `kubectl` usage in `.github/workflows/`. The Kubernetes/"archived VPS" description that used to be here was stale. See `docs/deployment/` for the current deployment guides.

## Current deployment path

Image builds and publishes run **only through GitHub Actions**:

- `.github/workflows/deploy-web.yml` — builds/publishes the web image to GHCR; a full-zone Cloudflare cache purge job follows the image push (`deploy-web.yml:106-131`). The host still pulls the image with `docker compose up -d` (see the "Known gap" comment at `deploy-web.yml:103-105`).
- `.github/workflows/deploy-backend.yml` — builds/publishes the api-backend, streaming-proxy and postgres images to GHCR (`deploy-backend.yml:27-160`); it has no host-deploy or cache-purge job.

Kubernetes manifests, when used, live under `config/kubernetes/base/` and `services/*/k8s/`; there is no root `k8s/` to apply with `kubectl apply -f k8s/`.

## Local / development

Use the compose files in the repository root (`docker-compose.yml`, `docker-compose.multi.yml`) and `config/docker/`. Validate the local environment with `scripts/docker/validate_dev_environment.sh`.

## Scripts that still exist

- `scripts/powershell/Deploy-Pistisai.ps1` — present (not archived).
- `scripts/powershell/BuildEnvironmentUtilities.ps1` — present.
- `scripts/version_manager.sh` — present; version bumps are also automated by `.github/workflows/auto-version-bump.yml` and `scripts/version_bump_kind.py`.

Scripts such as `sync_versions.sh` and `verify_deployment.sh` are not present; their versioning/verification roles are handled by CI, not by shell scripts in this repo.
