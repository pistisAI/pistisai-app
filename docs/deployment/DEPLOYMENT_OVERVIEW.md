# Pistisai Deployment Overview

This document provides a comprehensive overview of deployment options and strategies for Pistisai.

> **Current orientation**: Pistisai is agent-runtime-first and Tailscale-first. The setup wizard selects an agent runtime such as Hermes, OpenClaw, a compatible custom agent gateway, or an optional hosted agent runtime. Ollama, LM Studio, and similar model servers are support model providers for app-owned memory/background features, not primary app runtimes. Cloud deployment should focus on account sync, presence, web/mobile access, per-user cloud connectors, and optional per-user hosted agent runtime containers. Legacy streaming-proxy/tunnel components remain fallback architecture unless a deployment specifically depends on them.

## Start here

Production web hosting is [Web Deploy](../operations/cicd/WEB_DEPLOY.md) (Coolify). That path builds the Flutter web image from `Dockerfile.web`, publishes it from `.github/workflows/deploy-web.yml`, and routes through Traefik only after the container healthcheck passes.

The sections below are additional self-host and Kubernetes options. They are not the production web path.

## 📋 Table of Contents

- [Start here](#start-here)
- [Deployment Options](#deployment-options)
- [Multi-Container Architecture](#multi-container-architecture)
- [Deployment Scripts](#deployment-scripts)
- [Quality Standards](#quality-standards)
- [Versioning Strategy](#versioning-strategy)
- [Related Documentation](#related-documentation)

---

## Deployment Options

### Kubernetes deployment

Deploy the full Pistisai stack to **Kubernetes** using Dockerfiles and Kubernetes manifests. Works with:

- **Managed Kubernetes**: DigitalOcean Kubernetes (DOKS), Google GKE, AWS EKS, Azure AKS
- **Self-Hosted Kubernetes**: On-premises or your own infrastructure

```bash
# Build and push Docker images to your container registry
docker build -f config/docker/Dockerfile.web \
  -t your-registry.com/ghcr.io/pistisai/Pistisai/web:latest .
docker push your-registry.com/ghcr.io/pistisai/Pistisai/web:latest

docker build -f services/api-backend/Dockerfile.prod \
  -t your-registry.com/Pistisai/api:latest .
docker push your-registry.com/Pistisai/api:latest

# Deploy to Kubernetes (any cluster) — see config/kubernetes/ and services/*/k8s/
kubectl apply -f config/kubernetes/namespace.yaml
kubectl apply -f config/kubernetes/base/
```

**Benefits:**

- Scalable and secure environment for multiple users
- Automated SSL certificate management via cert-manager
- Auto-scaling and high availability
- Platform-agnostic (works with any Kubernetes cluster)
- Self-hosting option for businesses with security/compliance requirements

**Requirements:**

- Kubernetes cluster (managed or self-hosted)
- Container registry (Docker Hub, DigitalOcean Container Registry, self-hosted, etc.)
- Domain name with DNS configuration
- kubectl configured for your cluster

### 🏠 Self-Hosting Options

For self-hosted Kubernetes deployments (on-premises or private cloud):

- [Self-Hosting Guide](SELF_HOSTING.md) - General self-hosting information
- [Provider Infrastructure Guide](PROVIDER_INFRASTRUCTURE_GUIDE.md) - Server and provider infrastructure notes

### ⚠️ Legacy Single Container (Deprecated)

The legacy single-container deployment is deprecated and no longer supported. Please migrate to the multi-container architecture.

---

## Multi-Container Architecture

Pistisai features a modern multi-container architecture that provides:

### 🏗️ **Architecture Benefits**

- **Scalability**: Easily handle multiple users and connections
- **Resilience**: Isolated services prevent cascading failures
- **Maintainability**: Clear separation of concerns simplifies development and updates
- **Security**: Enhanced network policies and container isolation

### 🔧 **Key Containers**

- `nginx-proxy`: SSL termination and request routing
- `flutter-app`: The unified Flutter web application (UI, chat, marketing pages)
- `api-backend`: Core API, authentication, and streaming proxy management
- `tailscale-relay` / cloud connector: secure device mesh integration
- `streaming-proxy` (ephemeral): legacy/fallback proxies for older user-to-local-provider communication
- `certbot`: Automated SSL certificate management

For detailed information, see [System Architecture](../architecture/SYSTEM_ARCHITECTURE.md).

---

## Dockerfile-Based Deployment

Pistisai uses **Dockerfiles** for building container images, which are then deployed to **Kubernetes** (managed or self-hosted).

### 🐳 **Dockerfiles**

#### `config/docker/Dockerfile.web`

Builds the Flutter web application as a static site served by Nginx.

```bash
docker build -f config/docker/Dockerfile.web -t Pistisai-web:latest .
```

#### `services/api-backend/Dockerfile.prod`

Builds the Node.js API backend service.

```bash
docker build -f services/api-backend/Dockerfile.prod -t pistisai-api:latest .
```

### ☸️ **Kubernetes Deployment**

Deploy to any Kubernetes cluster (managed or self-hosted) using the manifests under
`config/kubernetes/` and per-service `k8s/` folders (there is no root `k8s/` directory):

```bash
# Shared / base manifests
kubectl apply -f config/kubernetes/namespace.yaml
kubectl apply -f config/kubernetes/base/

# Service-specific examples
kubectl apply -f services/api-backend/k8s/
kubectl apply -f web/k8s/
```

**Platform Options:**

- **Managed Kubernetes**: DigitalOcean (DOKS), Google GKE, AWS EKS, Azure AKS
- **Self-Hosted Kubernetes**: On-premises clusters, bare metal, or private cloud

For detailed deployment instructions, see:

- Kubernetes manifests: `config/kubernetes/`, `services/*/k8s/`, `web/k8s/`
- [Self-Hosting Guide](SELF_HOSTING.md) - For businesses deploying on-premises

---

## Quality Standards

### 🎯 Strict Deployment Policy

Pistisai enforces a **zero-tolerance deployment policy** for production:

- ✅ **Success**: Zero warnings AND zero errors required
- ❌ **Failure**: Any warning condition triggers automatic rollback
- 🔄 **Rollback**: Immediate restoration of previous version on any issue
- 🏆 **Quality**: Only perfect deployments reach production

### 📊 **Success Criteria**

- Perfect HTTP 200 responses (no redirects)
- Valid SSL certificates mandatory
- Clean container logs (no errors)
- Optimal system resources (<90% usage)
- Fully functional application health checks

See [Strict Deployment Policy](STRICT_DEPLOYMENT_POLICY.md) for complete details.

---

## Versioning Strategy

Pistisai tracks version in two synced files (see [AGENTS.md](../../AGENTS.md)):

- `assets/version.json` — `version` (semver) + integer `build_number`
- `pubspec.yaml` — `version: X.Y.Z+<build_number>`

Example shape: `1.1.46+45` (not a timestamped `YYYYMMDDHHMM` build id).

For packaging/version helper scripts, see [BUILD_SCRIPTS.md](../development/BUILD_SCRIPTS.md)
and [docs/development/versioning/](../development/versioning/).

---

## Related Documentation

### 📚 **Deployment Guides**

- [Complete Deployment Workflow](COMPLETE_DEPLOYMENT_WORKFLOW.md)
- [Strict Deployment Policy](STRICT_DEPLOYMENT_POLICY.md)
- [Deployment Testing Guide](DEPLOYMENT_TESTING_GUIDE.md)
- [Web Deploy](../operations/cicd/WEB_DEPLOY.md) — production Flutter web image on Coolify

### 🔧 **Operations**

- [Self-Hosting Guide](SELF_HOSTING.md)
- [Provider Infrastructure Guide](PROVIDER_INFRASTRUCTURE_GUIDE.md)

### ☸️ **Kubernetes Deployment**

- Kubernetes manifests live in `config/kubernetes/`, `services/*/k8s/`, and `web/k8s/`

### 🏗️ **Architecture**

- [System Architecture](../architecture/SYSTEM_ARCHITECTURE.md)
- [Secure Device Mesh](../architecture/SECURE_DEVICE_MESH.md)
- [Tunnel System](../architecture/TUNNEL_SYSTEM.md)

### 👨‍💻 **Development**

- [Developer Onboarding](../development/DEVELOPER_ONBOARDING.md)
- [API Documentation](../development/API_DOCUMENTATION.md)

---

_For questions about deployment, please see our [troubleshooting guide](../user-guide/TROUBLESHOOTING.md) or [open an issue](https://github.com/pistisAI/pistisai-app/issues)._
