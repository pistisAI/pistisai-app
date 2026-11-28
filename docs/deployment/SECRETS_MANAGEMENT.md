# Pistisai - Secrets Management Guide

This document lists the repository secrets actually referenced by the CI/CD workflows and the local environment file used for development.

## Overview

Secrets are sensitive values such as tokens and keys. They belong in GitHub Actions repository secrets or in a git-ignored local `.env`, never in version control. See `AGENTS.md` for the repository-wide personal-data rule.

## Secrets used by CI/CD

Verified against `secrets.*` references in `.github/workflows/`:

| Secret Name | Description | Used In |
| --- | --- | --- |
| `GITHUB_TOKEN` | Built-in Actions token used to log in to GHCR (`ghcr.io`) and push images | `deploy-web.yml`, `deploy-backend.yml` |
| `CLOUDFLARE_CACHE_PURGE_TOKEN` | Cloudflare API token with zone cache-purge permission | `deploy-web.yml` and `deploy-backend.yml` `purge_cache` |
| `CF_ZONE_ID` | Cloudflare zone ID for the full-zone purge request | `deploy-web.yml` and `deploy-backend.yml` `purge_cache` |
| `DOKPLOY_WEBHOOK_URL` | Dokploy webhook for the web application. A registry-push JSON body is posted; the tag is `latest` | `deploy-web.yml` `deploy_dokploy` |
| `DOKPLOY_API_URL` | Dokploy origin, for example `https://dokploy.example.com` | `deploy-web.yml` and `deploy-backend.yml` `deploy_dokploy` |
| `DOKPLOY_API_KEY` | Dokploy API key sent as `x-api-key` | `deploy-web.yml` and `deploy-backend.yml` `deploy_dokploy` |
| `DOKPLOY_WEB_APPLICATION_ID` | Dokploy application id for the web image | `deploy-web.yml` `deploy_dokploy` |
| `DOKPLOY_BACKEND_WEBHOOK_URL` | Dokploy webhook for the backend stack | `deploy-backend.yml` `deploy_dokploy` |
| `DOKPLOY_BACKEND_COMPOSE_ID` | Dokploy compose id for the backend stack | `deploy-backend.yml` `deploy_dokploy` |
| `BUMP_APP_ID` | GitHub App client ID used to mint a token for the release bump PR | `auto-version-bump.yml` |
| `BUMP_APP_KEY` | GitHub App private key for the same bump PR | `auto-version-bump.yml` |
| `SENTRY_DSN` | Sentry DSN referenced by CI workflows | `.github/workflows/` |

There are no `GCP_PROJECT_ID`, `GCP_SA_KEY`, `JWT_SECRET` or `JWT_AUDIENCE` repository secrets in these workflows. Deployments publish images to GHCR and purge Cloudflare via `CLOUDFLARE_CACHE_PURGE_TOKEN` / `CF_ZONE_ID`; sign-in uses Cloudflare Access (see [Authentication Quick Reference](../development/AUTHENTICATION_QUICK_REFERENCE.md)), not a CI-held JWT secret.

## Obtaining Secrets

### GitHub Actions

- `GITHUB_TOKEN` is provided automatically; no manual setup is needed.
- `BUMP_APP_ID` / `BUMP_APP_KEY` come from a GitHub App with permission to open and merge the automated version-bump PR.
- `CLOUDFLARE_CACHE_PURGE_TOKEN` / `CF_ZONE_ID`: create a Cloudflare API token scoped to **Zone → Cache Purge → Purge** for your zone, and copy the zone ID from the Cloudflare dashboard. The deploy fails if either is unset (see `deploy-web.yml` and `deploy-backend.yml`).
- Dokploy: create an API key in the Dokploy profile, and copy the webhook URL or the application/compose id from the service. Leave them unset to skip the trigger. Set the Actions variable `DOKPLOY_REQUIRED` to `true` to fail the job instead. `WEB_SERVED_VERSION_URL` and `BACKEND_SERVED_VERSION_URL` override the version check URLs.

### Local Development

1. Copy the tracked template: `cp .env.example .env`
2. Fill in the values for your local services. `.env` is git-ignored; never commit it.

`config/env.template` also exists as a CI/config template, but the documented local setup in [Self-Hosting](SELF_HOSTING.md) and [Docker Deployment](DOCKER_DEPLOYMENT.md) uses `.env.example`.

## Setting Up Secrets in GitHub

1. Navigate to the repository on GitHub.
2. Go to **Settings → Secrets and variables → Actions**.
3. Click **New repository secret**.
4. Add each secret with the exact name listed above.

## Security Best Practices

* **Never commit secrets to version control.**
* Use least-privilege Cloudflare tokens; the purge workflow only needs cache purge.
* Rotate credentials periodically.
* Use a secrets manager for local development where practical.
