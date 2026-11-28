# Provider Infrastructure Guide

## Overview

The desktop app is the hub. The hosted path is GitHub Actions building images into GHCR and Dokploy pulling them. Kubernetes manifests in the tree are legacy and unmaintained. Claims of an active Azure AKS deployment or a Docker Hub registry in older revisions of this guide were not backed by the code and are removed here.

Evidence: `.github/workflows/deploy-web.yml`, `.github/workflows/deploy-backend.yml`, [Dokploy](DOKPLOY.md), `docs/operations/cicd/WEB_DEPLOY.md`, `config/docker/docker-compose.dokploy-backend.yml`.

## Current Deployment Status

- **Build/publish**: GitHub Actions workflows on `main` (or `workflow_dispatch`). `deploy-web.yml` builds the production `Dockerfile.web` and pushes `ghcr.io/pistisai/pistisai-app-web:{version}` and `:latest`; `deploy-backend.yml` follows via `workflow_run` and pushes `ghcr.io/pistisai/pistisai-app/api-backend`, `/streaming-proxy` and `/postgres`.
- **Registry**: GHCR (`ghcr.io`). Actions pushes with `GITHUB_TOKEN`. Dokploy pulls with a registry credential that has `read:packages`. There is no Docker Hub publishing workflow.
- **Hosted runtime**: Dokploy. The web service is an Application on `ghcr.io/pistisai/pistisai-app-web:latest`, container port 80. The backend is the Compose file `config/docker/docker-compose.dokploy-backend.yml`. `deploy_dokploy` (`scripts/ci/trigger_dokploy_deploy.sh`, [#1056](https://github.com/pistisAI/pistisai-app/issues/1056)) runs after the image push. `docker-compose.prod.yml` and `config/docker/docker-compose.web.yml` are not the Dokploy files.
- **Cache**: `deploy-web.yml` and `deploy-backend.yml` purge the whole Cloudflare zone with `CLOUDFLARE_CACHE_PURGE_TOKEN` and `CF_ZONE_ID` after `deploy_dokploy`.
- **Authentication**: Cloudflare Access for the hosted sign-in path; Tailscale for the device mesh back to the desktop hub. See [Authentication Quick Reference](../development/AUTHENTICATION_QUICK_REFERENCE.md).
- **DNS/TLS**: attach the public hostname in Dokploy's Domains tab. Dokploy's Traefik routes to the container port. Do not publish host ports in the Compose file.

## Provider-Agnostic Architecture

### Kubernetes manifests (legacy, unmaintained)

- Shared Kubernetes manifests live in `config/kubernetes/base/` (namespace, HPAs, PDBs, network policies).
- Per-service manifests live in `services/api-backend/k8s/` (`deployment.yaml`, `service.yaml`, `ingress.yaml`).
- There is no root `k8s/` directory and no `web/k8s/` directory; older references to those paths are stale.
- These manifests are legacy and unmaintained. GitHub Actions does not apply them. The hosted path is Dokploy.

### Container strategy

- Production images are built by the GHCR workflows above from `Dockerfile.web` and the Dockerfiles under `config/docker/`.
- Dokploy backend Compose: `config/docker/docker-compose.dokploy-backend.yml`. `docker-compose.prod.yml` and `config/docker/docker-compose.web.yml` are not for Dokploy. Local development uses `docker-compose.yml`. There is no `docker-compose.production.yml` or `docker-compose.dev.yml`.

## Available Deployment Options

### 1. GitHub Actions → GHCR → Dokploy (hosted path)

- **Workflows**: [Web Deploy](../operations/cicd/WEB_DEPLOY.md), `.github/workflows/deploy-web.yml`, `.github/workflows/deploy-backend.yml`, [Dokploy](DOKPLOY.md).
- **Status**: the hosted path on `main`. The desktop app remains the hub.
- **Runs**: the web Application and the backend Compose service.

### 2. Kubernetes (legacy, unmaintained)

- **Manifests**: `config/kubernetes/base/`, `services/api-backend/k8s/`.
- **Status**: legacy and unmaintained. Not the hosted path. See [Deployment Overview](DEPLOYMENT_OVERVIEW.md).

### 3. Proxmox + k3s (legacy, unmaintained)

- **Runbook**: [k3s on Proxmox Deployment Workflow](K3S_PROXMOX_DEPLOYMENT_WORKFLOW.md).
- **Scripts**: `scripts/proxmox/create-k3s-template.sh`, `scripts/proxmox/clone-k3s-node.sh` (these exist).
- **Status**: legacy and unmaintained. Not part of the GHCR deploy chain.

### 4. Local development

- **Method**: local Flutter SDK plus `docker compose` against `docker-compose.yml`.
- **Status**: fully supported; see [Docker Development Environment](README_DOCKER.md).

## Removed / stale references

Earlier revisions of this guide pointed at paths that do not exist in the repository. They are not current deployment options:

- `docs/DEPLOYMENT/AKS_*.md`, `docs/ops/aws/`, `.kiro/steering/aws-infrastructure.md`, `docs/ops/kubernetes/`
- an Azure AKS setup script and `scripts/aws/` (not present)
- root `k8s/`, `web/k8s/`, `docs/DEPLOYMENT/` as a documentation root

Azure AKS and AWS EKS remain possible *targets* for an operator applying the standard manifests; they are not provisioned or active in this repository. There is no documented migration timeline or "provisioned for evaluation" infrastructure to rely on.

## Best Practices

### For operators

1. Use the GHCR workflows, [Web Deploy](../operations/cicd/WEB_DEPLOY.md), and [Dokploy](DOKPLOY.md) for hosted images.
2. Keep Dokploy domains, the GHCR credential, and the Compose environment in Dokploy. Actions triggers the pull through `deploy_dokploy`.
3. Leave the Kubernetes manifests alone. They are legacy.

### For developers

1. Keep the Dokploy Compose file free of Traefik labels and host ports. Dokploy adds routing when a domain is saved.
2. Test locally with `docker-compose.yml` before publishing an image. Validate the Dokploy file with `docker compose -f config/docker/docker-compose.dokploy-backend.yml config`.
3. Keep secrets in GitHub Actions secrets, the Dokploy environment, or `.env`, never in the Compose file (see [Secrets Management](SECRETS_MANAGEMENT.md)).

## Support and Troubleshooting

- **Deploy workflow failures**: inspect `.github/workflows/deploy-web.yml` run logs, including the GHCR push digest check and the Cloudflare purge step.
- **Site not updated after a run**: check `deploy_dokploy` and the Dokploy logs (see [Dokploy](DOKPLOY.md) and [Web Deploy](../operations/cicd/WEB_DEPLOY.md)).
- **Kubernetes**: those manifests are legacy and unmaintained. Hosted routing is Dokploy's Traefik, configured in the Domains tab.
- **Auth failures**: see [Authentication Quick Reference](../development/AUTHENTICATION_QUICK_REFERENCE.md).

## Conclusion

The hosted path is GitHub Actions → GHCR → Dokploy. The desktop app is the hub. Cloudflare Access covers hosted sign-in. Kubernetes and k3s manifests are legacy and unmaintained. Azure AKS and AWS EKS are not active deployments.
