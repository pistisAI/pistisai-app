# Deployment Documentation

Production web hosting starts at [Web Deploy](../operations/cicd/WEB_DEPLOY.md) (Coolify): the Flutter web image, Traefik health gate, and deploy workflow.

## Start Here

- [Web Deploy](../operations/cicd/WEB_DEPLOY.md) — production Flutter web image, Coolify, and Traefik health
- [Deployment Overview](DEPLOYMENT_OVERVIEW.md)
- [Complete Deployment Workflow](COMPLETE_DEPLOYMENT_WORKFLOW.md) — Kubernetes image build and apply sequence
- [Self Hosting](SELF_HOSTING.md)
- [Docker Deployment](DOCKER_DEPLOYMENT.md)
- [Strict Deployment Policy](STRICT_DEPLOYMENT_POLICY.md)
- [Secrets Management](SECRETS_MANAGEMENT.md)

## Installation Guides

- [Linux Installation](installation/LINUX.md)
- [Windows Installation](installation/WINDOWS.md)
- [macOS Installation](installation/MACOS.md)

## Kubernetes manifests

Manifests live under `config/kubernetes/`, `services/*/k8s/`, and `web/k8s/`. There is no root `k8s/` directory.

## Cloud And Provider Runbooks

- [Provider Infrastructure Guide](PROVIDER_INFRASTRUCTURE_GUIDE.md)
- [Cloudron Deployment](../../CloudronManifest.json)

Provider-specific notes are runbooks, not the production web path. Start at [Web Deploy](../operations/cicd/WEB_DEPLOY.md). Use [Deployment Overview](DEPLOYMENT_OVERVIEW.md) for the cross-provider model.

## Packaging And Releases

- [Versioning Strategy](VERSIONING_STRATEGY.md)
- [Deployment Testing Guide](DEPLOYMENT_TESTING_GUIDE.md)
- [Validation Testing Guide](VALIDATION_TESTING_GUIDE.md)

## Related Documentation

- [Documentation Hub](../README.md)
- [Operations Index](../operations/README.md)
- [Development Workflow](../development/DEVELOPMENT_WORKFLOW.md)
- [Security Policy](../governance/security/SECURITY.md)
