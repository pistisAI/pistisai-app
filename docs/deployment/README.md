# Deployment Documentation

This directory documents supported deployment paths for Pistisai.

## Start Here

- [Web Deploy](../operations/cicd/WEB_DEPLOY.md) — production Flutter web image and Docker Compose health
- Production deploy workflows: `.github/workflows/deploy-web.yml` (builds/pushes the web image to GHCR and purges the Cloudflare cache) and `.github/workflows/deploy-backend.yml` (builds/pushes the api-backend, streaming-proxy and postgres images to GHCR)
- [Deployment Overview](DEPLOYMENT_OVERVIEW.md)
- [Complete Deployment Workflow](COMPLETE_DEPLOYMENT_WORKFLOW.md)
- [Self Hosting](SELF_HOSTING.md)
- [Docker Deployment](DOCKER_DEPLOYMENT.md)
- [Strict Deployment Policy](STRICT_DEPLOYMENT_POLICY.md)
- [Secrets Management](SECRETS_MANAGEMENT.md)

## Installation Guides

- [Linux Installation](installation/LINUX.md)
- [Windows Installation](installation/WINDOWS.md)
- [macOS Installation](installation/MACOS.md)

## Kubernetes And GitOps

- [k3s Proxmox Deployment Workflow](K3S_PROXMOX_DEPLOYMENT_WORKFLOW.md)
- [ArgoCD Integration](../archive/historical-reports/deployment/ARGOCD_INTEGRATION.md)
- [ArgoCD Proxmox Management VM](../archive/historical-reports/deployment/ARGOCD_PROXMOX_MANAGEMENT_VM.md)

Kubernetes manifests live under `config/kubernetes/base/` (shared base) and `services/*/k8s/` (per-service examples). There is no root `k8s/` directory. Not every Kubernetes path has a README, so link to specific runbooks from this directory when documenting deployment procedures.

## Cloud And Provider Runbooks

- [Provider Infrastructure Guide](PROVIDER_INFRASTRUCTURE_GUIDE.md)
- [Cloudron Deployment](../../CloudronManifest.json)
- [Cloudflare/Chisel Deployment](CHISEL_DEPLOYMENT.md)

Provider-specific notes are runbooks, not universal architecture. Prefer [Deployment Overview](DEPLOYMENT_OVERVIEW.md) for the cross-provider model. Older tunnel/proxy runbooks are legacy or fallback material unless a deployment explicitly depends on them.

## Packaging And Releases

- [AUR Status](../archive/historical-reports/deployment/AUR_STATUS.md)
- [Versioning Strategy](VERSIONING_STRATEGY.md)
- [Deployment Testing Guide](../archive/historical-reports/deployment/DEPLOYMENT_TESTING_GUIDE.md)
- [Validation Testing Guide](VALIDATION_TESTING_GUIDE.md)
- [Tunnel Rollback Procedures](TUNNEL_ROLLBACK_PROCEDURES.md) — legacy/fallback tunnel runbook, kept live per #823 review

## Related Documentation

- [Documentation Hub](../README.md)
- [Operations Index](../operations/README.md)
- [Development Workflow](../archive/historical-reports/development/DEVELOPMENT_WORKFLOW.md)
- [Security Policy](../governance/security/SECURITY.md)
