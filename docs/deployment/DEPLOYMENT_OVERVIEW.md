# Pistisai Deployment Overview

The desktop app is the hub. Install it on the machine that stays on. It connects to the agent runtime (Hermes is the primary test path; OpenClaw and compatible gateways also work). Web, mobile, and other desktops connect through that hub, on the local network or over Tailscale. The hosted site is the browser client of the same model. It does not replace the desktop hub.

Hosted web and API run on Dokploy. GitHub Actions publishes images to GHCR, and Dokploy pulls them. Setup, secrets, rollback, and checks are in [Dokploy](DOKPLOY.md).

Coolify was removed in [#668](https://github.com/pistisAI/pistisai-app/issues/668). Kubernetes and k3s are legacy and unmaintained (see below). Deploys run only through GitHub Actions. There is no manual SSH deploy script.

## What runs where

| Path | Where it runs | How it is updated |
| --- | --- | --- |
| Desktop hub | The person's computer, when the hardware can run it | Desktop installers from GitHub Actions (`.github/workflows/build-desktop.yml`) |
| Mobile client | The phone | Android APKs from `.github/workflows/build-mobile.yml` |
| Hosted web | Dokploy Application, image `ghcr.io/pistisai/pistisai-app-web:latest`, container port 80 | `deploy-web.yml` pushes the image, then `deploy_dokploy` asks Dokploy to pull ([#1056](https://github.com/pistisAI/pistisai-app/issues/1056)) |
| Hosted API and streaming proxy | Dokploy Compose service from [`config/docker/docker-compose.dokploy-backend.yml`](../../config/docker/docker-compose.dokploy-backend.yml) | `deploy-backend.yml` pushes the images, then its `deploy_dokploy` job asks Dokploy to pull |

The API connects to PostgreSQL with `DB_HOST`, `DB_PORT`, `DB_NAME`, `DB_USER`, and `DB_PASSWORD` from the Dokploy environment. The Compose file does not start Postgres or Redis. `api-backend` and `streaming-proxy` do not open a Redis client.

Ollama and LM Studio are support model providers for app-owned features. They are not the hosted runtime.

## Hosted path (Dokploy)

1. Create a Dokploy Application for the web image and a Compose service for the backend file. Add a `ghcr.io` credential with `read:packages`.
2. Put runtime secrets (`DB_*`, Cloudflare Access, `PROXY_STATS_TOKEN`) in the Dokploy environment.
3. Put `DOKPLOY_WEBHOOK_URL` and `DOKPLOY_BACKEND_WEBHOOK_URL` in GitHub Actions secrets. Optional confirmation secrets: `DOKPLOY_API_URL`, `DOKPLOY_API_KEY`, `DOKPLOY_WEB_APPLICATION_ID`, `DOKPLOY_BACKEND_COMPOSE_ID`. Set the repository variable `DOKPLOY_REQUIRED` to `true` when a missing webhook must fail the job.
4. Merge to `main`. Web Deploy builds `Dockerfile.web`, pushes `ghcr.io/pistisai/pistisai-app-web`, triggers Dokploy, and purges the Cloudflare zone. Backend Deploy does the same for `ghcr.io/pistisai/pistisai-app/api-backend` and `ghcr.io/pistisai/pistisai-app/streaming-proxy`.

The `deploy_dokploy` jobs and `scripts/ci/trigger_dokploy_deploy.sh` land with #1056. This overview names them. It does not change the workflow files.

`docker-compose.prod.yml` is a legacy Swarm-style stack (its own Traefik, Redis, and published ports). `config/docker/docker-compose.web.yml` builds a prebuilt `build/web` tree for a local Compose run. Neither file is what Dokploy runs.

Local development still uses the repo-root `docker-compose.yml` and a local Flutter SDK. See [Docker development environment](README_DOCKER.md).

## Legacy: Kubernetes and k3s

Manifests under `config/kubernetes/base/` and `services/*/k8s/` are legacy and unmaintained. So is the Proxmox k3s runbook, [k3s on Proxmox Deployment Workflow](K3S_PROXMOX_DEPLOYMENT_WORKFLOW.md), and the archived ArgoCD notes linked from [the deployment index](README.md). Do not treat them as the hosted path or as a recommended cluster. They remain in the tree so an operator can read what used to be applied. Nothing in `.github/workflows/` applies them.

## Compose files

| File | Role |
| --- | --- |
| `config/docker/docker-compose.dokploy-backend.yml` | Hosted backend on Dokploy. GHCR images, `IMAGE_TAG`, no Traefik labels, no host ports. |
| `config/docker/docker-compose.web.yml` | Not for Dokploy. Local run of a prebuilt web tree. |
| `docker-compose.prod.yml` | Not for Dokploy. Legacy stack with its own Traefik and Redis. |
| `docker-compose.yml` | Local backing services for development. |

## Versioning

Version is tracked in two files that stay in sync:

- `assets/version.json` — `version` (semver) plus integer `build_number`
- `pubspec.yaml` — `version: X.Y.Z+<build_number>`

Web image tags use the `version` field. Backend image tags use `v` plus that version with the `+build` suffix removed, and `build-<version>-<shortsha>`. Rollback sets the Dokploy web tag or the Compose `IMAGE_TAG` to one of those published tags. See [Dokploy](DOKPLOY.md).

## Related documentation

- [Dokploy](DOKPLOY.md) — setup, secrets, rollback, verification
- [Deployment index](README.md)
- [Web Deploy](../operations/cicd/WEB_DEPLOY.md)
- [Deploy trigger chain](../operations/cicd/DEPLOY_TRIGGER_CHAIN.md)
- [Secrets Management](SECRETS_MANAGEMENT.md)
- [Release workflow](../development/release/RELEASE_WORKFLOW.md)
- [Strict Deployment Policy](STRICT_DEPLOYMENT_POLICY.md)
- [System Architecture](../architecture/SYSTEM_ARCHITECTURE.md)
