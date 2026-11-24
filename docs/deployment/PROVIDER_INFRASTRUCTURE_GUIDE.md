# Provider Infrastructure Guide

## Overview

This document describes the deployment setup that exists in the repository today. The app is provider-agnostic at the manifest level, but the supported production path is GitHub Actions building images into GHCR and a host running them with Docker Compose. Claims of an active Azure AKS deployment or a Docker Hub registry in older revisions of this guide were not backed by the code and are removed here.

Evidence: `.github/workflows/deploy-web.yml`, `.github/workflows/deploy-backend.yml`, `docs/operations/cicd/WEB_DEPLOY.md`, `config/kubernetes/`, `config/docker/`.

## Current Deployment Status

- **Build/publish**: GitHub Actions workflows on `main` (or `workflow_dispatch`). `deploy-web.yml` builds the production `Dockerfile.web` and pushes `ghcr.io/pistisai/pistisai-app-web:{version}` and `:latest`; `deploy-backend.yml` follows via `workflow_run` and pushes `ghcr.io/<repo>/api-backend`, `/streaming-proxy` and `/postgres`.
- **Registry**: GHCR (`ghcr.io`), authenticated with `GITHUB_TOKEN`. There is no Docker Hub publishing workflow.
- **Host runtime**: the host pulls the published image and runs `docker compose -f config/docker/docker-compose.web.yml up -d`. The workflow itself notes that the host pull is still manual.
- **Cache**: `deploy-web.yml` purges the whole Cloudflare zone with `CLOUDFLARE_CACHE_PURGE_TOKEN` and `CF_ZONE_ID`.
- **Authentication**: Cloudflare Access for the free tunnel path; customer-owned VPN or Tailscale for business deployments. See [Authentication Quick Reference](../development/AUTHENTICATION_QUICK_REFERENCE.md).
- **DNS/SSL**: Cloudflare in front of the tunnel; TLS termination is handled by the host ingress / Cloudflare Tunnel, not by a cloud load balancer.

## Provider-Agnostic Architecture

### Kubernetes-native design

- Shared Kubernetes manifests live in `config/kubernetes/base/` (namespace, HPAs, PDBs, network policies).
- Per-service manifests live in `services/api-backend/k8s/` (`deployment.yaml`, `service.yaml`, `ingress.yaml`).
- There is no root `k8s/` directory and no `web/k8s/` directory; older references to those paths are stale.
- Manifests use standard Kubernetes APIs, so they can be applied to any compatible cluster by an operator. This is a self-hosting option, not the automated production path.

### Container strategy

- Production images are built by the GHCR workflows above from `Dockerfile.web` and the Dockerfiles under `config/docker/`.
- Compose definitions for self-hosting: `docker-compose.yml`, `docker-compose.prod.yml`, and `config/docker/docker-compose.web.yml`. There is no `docker-compose.production.yml` or `docker-compose.dev.yml`.

## Available Deployment Options

### 1. GitHub Actions → GHCR (current production)

- **Workflows**: [Web Deploy](../operations/cicd/WEB_DEPLOY.md), `.github/workflows/deploy-web.yml`, `.github/workflows/deploy-backend.yml`.
- **Status**: the automated build/publish path on `main`.
- **Recommended for**: production web and backend images.

### 2. Self-hosted / Kubernetes

- **Manifests**: `config/kubernetes/base/`, `services/api-backend/k8s/`.
- **Requirements**: a Kubernetes cluster (1.24+) with `kubectl` configured, or a Docker Compose host.
- **Status**: supported as a manual/operator path. See [Self-Hosting Guide](SELF_HOSTING.md) and [Deployment Overview](DEPLOYMENT_OVERVIEW.md).

### 3. Proxmox + k3s

- **Runbook**: [k3s on Proxmox Deployment Workflow](K3S_PROXMOX_DEPLOYMENT_WORKFLOW.md).
- **Scripts**: `scripts/proxmox/create-k3s-template.sh`, `scripts/proxmox/clone-k3s-node.sh` (these exist).
- **Status**: operator-run alternative; not part of the GHCR deploy chain.

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

1. Use the GHCR workflows and [Web Deploy](../operations/cicd/WEB_DEPLOY.md) for production images.
2. Keep host configuration (the `docker compose up -d` pull) in your own runbook; it is not automated by Actions.
3. Use standard manifests for self-hosted clusters; treat provider-specific setup as local configuration.

### For developers

1. Avoid vendor lock-in: use standard Kubernetes APIs and avoid provider-specific fields in committed manifests.
2. Test locally with `docker-compose.yml` before publishing an image.
3. Keep secrets in GitHub Actions secrets or `.env`, never in manifests (see [Secrets Management](SECRETS_MANAGEMENT.md)).

## Support and Troubleshooting

- **Deploy workflow failures**: inspect `.github/workflows/deploy-web.yml` run logs, including the GHCR push digest check and the Cloudflare purge step.
- **Site not updated after a run**: the host pulls the image separately; re-run the workflow / purge again if the host deployed late (see [Web Deploy](../operations/cicd/WEB_DEPLOY.md)).
- **Kubernetes issues**: check `config/kubernetes/base/` and `services/api-backend/k8s/`; use standard `kubectl` diagnostics.
- **Auth failures**: see [Authentication Quick Reference](../development/AUTHENTICATION_QUICK_REFERENCE.md).

## Conclusion

The supported production reality is GitHub Actions → GHCR → host Docker Compose, with Cloudflare Access for sign-in and Kubernetes manifests available for self-hosting. Azure AKS and AWS EKS are only potential targets for operators, not active deployments.
