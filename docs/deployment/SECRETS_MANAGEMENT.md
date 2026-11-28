# Pistisai - Secrets Management Guide

This document lists the repository secrets actually referenced by the CI/CD workflows and the local environment file used for development.

## Overview

Secrets are sensitive values such as tokens and keys. They belong in GitHub Actions repository secrets or in a git-ignored local `.env`, never in version control. See `AGENTS.md` for the repository-wide personal-data rule.

## Secrets used by CI/CD

Verified against `secrets.*` references in `.github/workflows/`:

| Secret Name | Description | Used In |
| --- | --- | --- |
| `GITHUB_TOKEN` | Built-in Actions token used to log in to GHCR (`ghcr.io`) and push images | `deploy-web.yml`, `deploy-backend.yml` |
| `CLOUDFLARE_CACHE_PURGE_TOKEN` | Cloudflare API token with zone cache-purge permission | `deploy-web.yml` `purge_cache` job |
| `CF_ZONE_ID` | Cloudflare zone ID for the full-zone purge request | `deploy-web.yml` `purge_cache` job |
| `BUMP_APP_ID` | GitHub App client ID used to mint a token for the release bump PR | `auto-version-bump.yml` |
| `BUMP_APP_KEY` | GitHub App private key for the same bump PR | `auto-version-bump.yml` |
| `SENTRY_DSN` | Sentry DSN referenced by CI workflows | `.github/workflows/` |
| `DOKPLOY_WEBHOOK_URL` | Dokploy deploy webhook for the web Application | `deploy-web.yml` `deploy_dokploy` job ([#1056](https://github.com/pistisAI/pistisai-app/issues/1056)) |
| `DOKPLOY_BACKEND_WEBHOOK_URL` | Dokploy deploy webhook for the backend Compose service | `deploy-backend.yml` `deploy_dokploy` job (#1056) |
| `DOKPLOY_API_URL` | Optional Dokploy API base URL, used to confirm a deploy after the webhook | `deploy_dokploy` jobs |
| `DOKPLOY_API_KEY` | Optional Dokploy API key for that confirmation | `deploy_dokploy` jobs |
| `DOKPLOY_WEB_APPLICATION_ID` | Optional Dokploy id of the web Application | `deploy-web.yml` `deploy_dokploy` |
| `DOKPLOY_BACKEND_COMPOSE_ID` | Optional Dokploy id of the backend Compose service | `deploy-backend.yml` `deploy_dokploy` |

`DOKPLOY_REQUIRED` is a repository **variable**, not a secret. Set it to `true` when a missing webhook must fail `deploy_dokploy`. When it is unset, that job skips the trigger and the image publish still succeeds. The job and `scripts/ci/trigger_dokploy_deploy.sh` are added for #1056. See [Dokploy](DOKPLOY.md).

Runtime values for the containers (`DB_HOST`, `DB_USER`, `DB_PASSWORD`, `DB_NAME`, `CF_ACCESS_TEAM_DOMAIN`, `CF_ACCESS_AUD`, `PROXY_STATS_TOKEN`, `IMAGE_TAG`) live in the Dokploy environment, not in GitHub Actions. The Compose file interpolates them and does not store them.

There are no `GCP_PROJECT_ID`, `GCP_SA_KEY`, `JWT_SECRET` or `JWT_AUDIENCE` repository secrets in these workflows. Deployments publish images to GHCR, ask Dokploy to pull them, and purge Cloudflare via `CLOUDFLARE_CACHE_PURGE_TOKEN` / `CF_ZONE_ID`; sign-in uses Cloudflare Access (see [Authentication Quick Reference](../development/AUTHENTICATION_QUICK_REFERENCE.md)), not a CI-held JWT secret.

## Obtaining Secrets

### GitHub Actions

- `GITHUB_TOKEN` is provided automatically; no manual setup is needed.
- `BUMP_APP_ID` / `BUMP_APP_KEY` come from a GitHub App with permission to open and merge the automated version-bump PR.
- `CLOUDFLARE_CACHE_PURGE_TOKEN` / `CF_ZONE_ID`: create a Cloudflare API token scoped to **Zone → Cache Purge → Purge** for your zone, and copy the zone ID from the Cloudflare dashboard. The deploy fails if either is unset (see `deploy-web.yml`).
- `DOKPLOY_WEBHOOK_URL` / `DOKPLOY_BACKEND_WEBHOOK_URL`: copy each from the Dokploy service's deploy webhook. The optional `DOKPLOY_API_*` secrets and application ids are only for the confirmation step in `scripts/ci/trigger_dokploy_deploy.sh`.
- `DOKPLOY_REQUIRED`: repository variable. `true` fails the job when the webhook secret is missing.

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
