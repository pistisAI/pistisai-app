# Pistisai Strict Deployment Policy

## Overview

Pistisai implements a **zero-tolerance deployment policy** where any warning or error condition results in deployment failure. This ensures that only the highest quality deployments reach production. Git version control provides rollback capabilities when needed.

## Strict Success Criteria

### ✅ Success Definition

A deployment is considered successful **ONLY** when:

- **Zero warnings** detected during verification
- **Zero errors** detected during verification
- All verification checks pass with perfect scores

### ❌ Failure Triggers

Any of the following conditions will trigger immediate deployment failure:

- Non-200 HTTP response codes (excluding expected redirects to HTTPS)
- Non-200 HTTPS response codes
- Invalid or missing SSL certificates
- Container errors in logs
- High system resource usage (>90% disk or memory)
- Application health check failures
- Any warning condition whatsoever

**Note**: HTTP redirects (301/302) are now considered expected behavior for HTTPS enforcement and do not trigger deployment failure.

## Verification Components

### 1. HTTP Endpoint Verification

- **Requirement**: HTTP 200 responses or expected redirects to HTTPS (301/302)
- **Failure**: Error responses (4xx/5xx) or unexpected redirect behavior
- **Rationale**: HTTPS redirects are expected security behavior; other errors indicate problems

### 2. HTTPS and SSL Verification

- **Requirement**: Valid SSL certificates and HTTP 200 responses
- **Failure**: Invalid certificates, certificate warnings, or non-200 responses
- **Rationale**: Security and reliability require perfect SSL configuration

### 3. Container Health Verification

- **Requirement**: All containers running without any errors in logs
- **Failure**: Any error messages in recent container logs
- **Rationale**: Clean logs indicate stable, error-free operation

### 4. System Resource Verification

- **Requirement**: Disk and memory usage below 90%
- **Failure**: High resource usage that could impact performance
- **Rationale**: Optimal resource levels ensure stable operation

### 5. Application Health Verification

- **Requirement**: Version endpoint accessible with valid JSON response
- **Failure**: Endpoint not accessible or invalid response
- **Rationale**: Application must be fully functional and responsive

## Deployment Workflow

### Automated Process

1. **Pre-deployment checks** - Environment validation
2. **Application build** - Flutter web compilation in `.github/workflows/deploy-web.yml`
3. **Image publication** - GitHub Actions pushes the image to GHCR (`ghcr.io/pistisai/pistisai-app-web`). The `deploy_dokploy` job asks Dokploy to pull it into the web Application (container port 80). There is no SSH upload. See [Dokploy](DOKPLOY.md).
4. **STRICT verification** - Zero-tolerance quality checks
5. **Success/Failure decision** - Based on strict criteria

Production deploys are GitHub Actions runs on `main` (or `workflow_dispatch`) into Dokploy. See [Web Deploy](../operations/cicd/WEB_DEPLOY.md), [Dokploy](DOKPLOY.md), and `.github/workflows/deploy-web.yml`.

### Rollback Mechanism

- **Trigger**: Any warning or error during verification
- **Process**: Use Git version control to restore previous deployment
- **Command**: `git checkout <previous-commit>` followed by redeployment
- **Safety**: Git history provides complete deployment rollback capability

## Benefits of Strict Policy

### Quality Assurance

- **Highest Standards**: Only perfect deployments reach production
- **Consistency**: Every production deployment meets identical quality criteria
- **Reliability**: Eliminates partial or degraded deployments

### Risk Mitigation

- **Zero Tolerance**: No compromise on quality standards
- **Automatic Protection**: Prevents problematic deployments from staying live
- **Git-Based Recovery**: Version control provides reliable rollback capability

### Operational Excellence

- **Predictable Results**: Clear success/failure criteria
- **Automated Decision Making**: No manual judgment calls required
- **Continuous Improvement**: Forces resolution of all issues

## Implementation Details

### Verification Script

There is no dedicated verify-deployment script in this repository. The zero-tolerance checks are the healthchecks and verification scripts that exist today:

- **Web image healthcheck**: the production image requests `http://127.0.0.1/` (see [Web Deploy](../operations/cicd/WEB_DEPLOY.md)). `config/docker/docker-compose.web.yml` is not the Dokploy Application.
- **Kubernetes tunnel scripts** (`scripts/verify-k8s-tunnel-only.sh`, `scripts/integration-test-deployments.sh`) belong to the legacy, unmaintained cluster path. They are not the hosted check.
- **Mode**: Strict verification with zero tolerance for warnings or errors.
- **Output**: Clear success/failure indication with detailed reasoning.

### Deployment Script

There is no dedicated complete-deployment script. Production deploys are driven by GitHub Actions:

- **Entry point**: `.github/workflows/deploy-web.yml` (`workflow_dispatch` or push to `main`), with `.github/workflows/deploy-backend.yml` following via `workflow_run`.
- **Mode**: Builds/pushes images to GHCR; `deploy_dokploy` asks Dokploy to pull (`DOKPLOY_WEBHOOK_URL` / `DOKPLOY_BACKEND_WEBHOOK_URL`).
- **Rollback**: set the Dokploy image tag or Compose `IMAGE_TAG` to a previously published tag. See [Dokploy](DOKPLOY.md).

### Exit Codes

- **0**: Perfect deployment (zero warnings, zero errors)
- **1**: Deployment failure (any warning or error detected)

## Git-Based Backup Strategy

### Overview

Pistisai uses Git version control as the primary backup and rollback mechanism, eliminating the need for separate backup systems during deployment.

### Benefits

- **Complete History**: Git maintains full deployment history
- **Atomic Operations**: Each deployment is a complete, versioned state
- **Reliable Rollback**: Guaranteed restoration to any previous working state
- **No Storage Overhead**: No duplicate backup files consuming disk space
- **Audit Trail**: Complete change tracking and deployment history

### Rollback Procedure

If a deployment fails or issues are discovered:

1. **Identify the previous image tag** from the GitHub Actions run that published it. Web tags are the `version` field in `assets/version.json`. Backend tags are `v<version>` and `build-<version>-<shortsha>`.

2. **Roll back in Dokploy.** Web Application: set the image tag and redeploy. Backend Compose: set `IMAGE_TAG` to that tag and redeploy. Do not check out an old commit on the server, and do not force-push `main`.

3. **A bad commit on `main`** is reverted with a normal pull request. Merging it re-runs `deploy-web.yml` and `deploy_dokploy`.

4. **Verify Rollback Success**:

   Confirm Dokploy reports the Application healthy and the public hostname serves the rolled-back version. See [Dokploy](DOKPLOY.md).

### Best Practices

- **Always commit before deployment**: Ensure current state is saved
- **Use descriptive commit messages**: Enable easy identification of deployment states
- **Tag stable releases**: Mark known-good deployments for easy rollback
- **Monitor deployment logs**: Early detection prevents need for rollback

## Configuration

### Default Settings

- **Deploy entry point**: GitHub Actions on `main` — `.github/workflows/deploy-web.yml`, then `.github/workflows/deploy-backend.yml` via `workflow_run`
- **Image registry**: `ghcr.io` (GHCR), authenticated with `GITHUB_TOKEN`
- **Hosted runtime**: Dokploy (web Application on port 80; backend Compose `config/docker/docker-compose.dokploy-backend.yml`). `docker-compose.prod.yml` and `config/docker/docker-compose.web.yml` are not the Dokploy files.
- **Resource Thresholds**: 90% for disk and memory
- **HTTP Requirements**: 200 responses or expected HTTPS redirects (301/302)
- **SSL Requirements**: Valid certificates mandatory

### Customization

The strict policy is enforced by default but can be understood through:

- Script comments and documentation
- Verification step output messages
- Deployment report generation

## Troubleshooting

### Common Failure Scenarios

#### HTTP Error Responses

- **Issue**: Server returns 4xx/5xx error codes
- **Solution**: Fix application or server configuration issues
- **Prevention**: Ensure proper nginx/web server configuration and application health

**Note**: HTTP redirects (301/302) to HTTPS are expected behavior and not considered failures.

#### SSL Certificate Issues

- **Issue**: Invalid, expired, or missing certificates
- **Solution**: Renew or properly configure SSL certificates
- **Prevention**: Monitor certificate expiration dates

#### Container Errors

- **Issue**: Application errors in container logs
- **Solution**: Fix application issues before deployment
- **Prevention**: Thorough testing in staging environment

#### High Resource Usage

- **Issue**: Disk or memory usage above 90%
- **Solution**: Clean up resources or upgrade server capacity
- **Prevention**: Regular resource monitoring and maintenance

## Best Practices

### Pre-Deployment

1. **Test thoroughly** in staging environment
2. **Verify all dependencies** are properly configured
3. **Check resource availability** on target server
4. **Ensure SSL certificates** are valid and current

### During Deployment

1. **Monitor deployment logs** for any issues
2. **Verify each phase** completes successfully
3. **Trust the automated process** - manual intervention not required

### Post-Deployment

1. **Review verification results** even on success
2. **Monitor application performance** after deployment
3. **Address any near-threshold conditions** proactively

## Conclusion

The strict deployment policy ensures Pistisai maintains the highest production quality standards. By requiring zero warnings and zero errors, we guarantee that every production deployment is stable, secure, and fully functional.

This policy prioritizes reliability over speed, ensuring users always experience a high-quality, properly functioning application.
