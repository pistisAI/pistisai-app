# Operations Documentation

Operational documentation covers running, monitoring, recovering, and securing Pistisai infrastructure.

## Primary Operations

- [Deployment Index](../deployment/README.md)
- [Dokploy](../deployment/DOKPLOY.md)
- [Self Hosting](../deployment/SELF_HOSTING.md)
- [Docker Deployment](../deployment/DOCKER_DEPLOYMENT.md)
- [Complete Deployment Workflow](../deployment/DEPLOYMENT_OVERVIEW.md)
- [Strict Deployment Policy](../deployment/STRICT_DEPLOYMENT_POLICY.md)

## CI/CD

- [CI/CD Quick Reference](cicd/CI_CD_QUICK_REFERENCE.md)
- [Web Deploy](cicd/WEB_DEPLOY.md)
- [Unified Deployment Workflow](../archive/historical-reports/operations/cicd/UNIFIED_DEPLOYMENT_WORKFLOW.md) — historical; the workflow file it names is not in the repo

## Backend Operations

- [Backend Operations Index](backend/README.md)
- [Backup Recovery](backend/BACKUP_RECOVERY_QUICK_REFERENCE.md)
- [Database Performance](backend/DATABASE_PERFORMANCE_QUICK_REFERENCE.md)
- [Error Recovery](backend/ERROR_RECOVERY_QUICK_REFERENCE.md)
- [Prometheus Metrics](backend/PROMETHEUS_METRICS_QUICK_REFERENCE.md)

## Security Operations

- [Backend Security](security/BACKEND_SECURITY.md)
- [Rate Limiting](security/RATE_LIMITING.md)
- [RBAC Guide](security/RBAC_GUIDE.md)

## Current Baseline

The desktop app is the hub. Hosted web and API run on Dokploy (GitHub Actions publishes the images). Kubernetes and k3s manifests under `config/kubernetes/` and `services/*/k8s/` are legacy and unmaintained. Local Docker Compose (`docker-compose.yml`) is for development. `docker-compose.prod.yml` and `config/docker/docker-compose.web.yml` are not the Dokploy files.
