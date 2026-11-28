# Hosted deploys with Dokploy

The desktop app is the hub. Web, mobile, and other desktops connect through that first desktop install. Hosted web and API are the optional cloud path, and they run on [Dokploy](https://dokploy.com). GitHub Actions builds the images and Dokploy pulls them. Nobody deploys by SSH.

Coolify was removed in [#668](https://github.com/pistisAI/pistisai-app/issues/668). Kubernetes and k3s manifests under `config/kubernetes/` and `services/*/k8s/` are legacy and unmaintained. They are not this path.

`docker-compose.prod.yml` and `config/docker/docker-compose.web.yml` are not Dokploy files. Each of those files says so at the top. The backend Compose file for Dokploy is [`config/docker/docker-compose.dokploy-backend.yml`](../../config/docker/docker-compose.dokploy-backend.yml).

## What to create in Dokploy

Two services, in one Dokploy project:

| Service | Dokploy type | Image or file | Container port |
| --- | --- | --- | --- |
| Web | Application | `ghcr.io/pistisai/pistisai-app-web:latest` | 80 |
| Backend | Compose | `config/docker/docker-compose.dokploy-backend.yml` | 8080 (`api-backend`), 3001 (`streaming-proxy`) |

Attach each public hostname in the Dokploy Domains tab. Dokploy's Traefik terminates TLS and routes to the container port. Do not publish host ports, and do not put Traefik labels in the Compose file. Dokploy adds the routing labels when you save the domain.

Both Compose services join the external `dokploy-network` that Dokploy creates, which is how Traefik reaches them. Do not set `container_name`.

### GHCR registry credential

In Dokploy, add a registry credential the host uses to pull:

- Registry: `ghcr.io`
- Username: a GitHub account that can read the `pistisai` packages
- Password: a personal access token with the `read:packages` scope

The web Application and the backend Compose service both need that credential. GitHub Actions pushes with `GITHUB_TOKEN`. The Dokploy host pulls with the token above. Those are different credentials.

Images the workflows publish:

- Web (`.github/workflows/deploy-web.yml`): `ghcr.io/pistisai/pistisai-app-web:<version>` and `:latest`. `<version>` is the `version` field in `assets/version.json`.
- API (`.github/workflows/deploy-backend.yml`): `ghcr.io/pistisai/pistisai-app/api-backend` tagged `latest`, `v<version>`, and `build-<version>-<shortsha>`.
- Streaming proxy: `ghcr.io/pistisai/pistisai-app/streaming-proxy` with the same three tags.
- That workflow also publishes `ghcr.io/pistisai/pistisai-app/postgres`. This Compose file does not run it.

## Backend Compose

[`config/docker/docker-compose.dokploy-backend.yml`](../../config/docker/docker-compose.dokploy-backend.yml) starts two services from those GHCR images:

- `api-backend` listens on 8080. The image healthcheck is `curl --fail http://127.0.0.1:8080/health`. The process opens a PostgreSQL pool from `DB_HOST`, `DB_PORT`, `DB_NAME`, `DB_USER`, and `DB_PASSWORD` (`services/api-backend/database/db-pool.js`).
- `streaming-proxy` listens on 3001 and runs `proxy-server.js`. Its image has no `curl`, so the Compose healthcheck uses Node's `fetch` against `http://127.0.0.1:3001/health`.

`IMAGE_TAG` selects the tag for both images. Leave it unset to pull `latest`.

Redis is not in the file. Neither service opens a Redis client. Rate limiting and the polling bridge keep their state in process memory.

Postgres is not in the file. Point `DB_*` at the database you already run in Dokploy (or another Postgres the containers can reach on `dokploy-network`). `DATABASE_URL` is optional and is read by the webhook route and the seed script, not by the pool.

### Environment on the Compose service

Set these in the Dokploy environment for the Compose service. They are interpolated into the containers. Do not commit the values.

| Variable | Used by | Required |
| --- | --- | --- |
| `IMAGE_TAG` | both images | No. Defaults to `latest`. Set to `vX.Y.Z` or `build-X.Y.Z-<shortsha>` to roll back. |
| `DB_HOST` | api-backend pool | Yes |
| `DB_PORT` | api-backend pool | No. Defaults to `5432`. |
| `DB_NAME` | api-backend pool | Yes |
| `DB_USER` | api-backend pool | Yes |
| `DB_PASSWORD` | api-backend pool | Yes |
| `DB_SSL` | api-backend pool | No. Set to `true` to verify the server certificate. |
| `DATABASE_URL` | webhook route and seeds | No |
| `CF_ACCESS_TEAM_DOMAIN` | api-backend auth | Yes for any route that checks Cloudflare Access |
| `CF_ACCESS_AUD` | api-backend auth | Yes for any route that checks Cloudflare Access |
| `SENTRY_DSN` | both | No |
| `PROXY_STATS_TOKEN` | streaming-proxy `/stats` | Yes if anything calls `/stats`. Empty token fail-closes that route with 401. |
| `OPENCLAW_WEBHOOK_SECRET` | api-backend OpenClaw webhook route | No. The route reads it when present. |

The streaming-proxy image does not verify a Cloudflare Access token itself. Put Access in front of that hostname if the route must be authenticated.

Validate the file locally before changing it:

```bash
docker compose -f config/docker/docker-compose.dokploy-backend.yml config
```

Unset variables render as empty strings. `IMAGE_TAG` renders as `latest`.

## GitHub Actions trigger

Deploys run only through GitHub Actions. Pushing to `main` starts [Web Deploy](../operations/cicd/WEB_DEPLOY.md). [Backend Deploy](../../.github/workflows/deploy-backend.yml) follows on `workflow_run`.

Each of those workflows has a `deploy_dokploy` job that calls `scripts/ci/trigger_dokploy_deploy.sh` ([#1056](https://github.com/pistisAI/pistisai-app/issues/1056)). The job runs after the image push and before the full-zone Cloudflare purge, so the purge waits until Dokploy has been asked to pull. This document describes that job. It does not edit `.github/workflows/deploy-*.yml` or the script.

Repository secrets:

| Name | Role |
| --- | --- |
| `DOKPLOY_WEBHOOK_URL` | Deploy webhook for the web Application. `deploy-web.yml` posts here. |
| `DOKPLOY_BACKEND_WEBHOOK_URL` | Deploy webhook for the backend Compose service. `deploy-backend.yml` posts here. |
| `DOKPLOY_API_URL` | Optional. Dokploy API base URL, used to confirm the deploy after the webhook. |
| `DOKPLOY_API_KEY` | Optional. API key for that confirmation. |
| `DOKPLOY_WEB_APPLICATION_ID` | Optional. Dokploy id of the web Application. |
| `DOKPLOY_BACKEND_COMPOSE_ID` | Optional. Dokploy id of the backend Compose service. |

Repository variable (Settings → Secrets and variables → Actions → Variables), not a secret:

| Name | Role |
| --- | --- |
| `DOKPLOY_REQUIRED` | When `true`, a missing webhook secret fails the `deploy_dokploy` job. When unset or any other value, the job skips the trigger and the image publish still succeeds. |

Copy the webhook URL from the Dokploy service (Deployments → Webhook) into the matching secret. The optional API values are only for the confirmation step. The webhook is what tells Dokploy to pull.

`CLOUDFLARE_CACHE_PURGE_TOKEN` and `CF_ZONE_ID` still gate the purge. The purge fails the deploy when either is missing or Cloudflare does not return `success`. See [Secrets Management](SECRETS_MANAGEMENT.md).

## Rollback

Roll back by tag. Do not SSH to a host and do not rewrite `main` to force an old image.

Web Application: set the image tag from `latest` to the previous `assets/version.json` `version` (the tag `deploy-web.yml` pushed) and redeploy the Application in Dokploy.

Backend Compose: set `IMAGE_TAG` to the previous `vX.Y.Z` or `build-X.Y.Z-<shortsha>` tag and redeploy the Compose service. Both services move together because they share `IMAGE_TAG`.

## Verification

After Dokploy marks the deploy healthy:

1. Web: open the hostname attached to the Application. The Flutter shell loads from port 80. The image healthcheck requests `http://127.0.0.1/` with `wget`.
2. API: request `/health` on the hostname attached to `api-backend` (container port 8080). Expect a JSON health document.
3. Streaming proxy: request `/health` on the hostname attached to `streaming-proxy` (container port 3001). Expect `{"status":"healthy",...}`.
4. Actions: `gh run list --workflow=deploy-web.yml --limit 3` and the same for `deploy-backend.yml`. The `deploy_dokploy` job and the purge job both succeed when `DOKPLOY_REQUIRED` is `true`.

A registry pull error in the Dokploy logs means the GHCR credential is missing `read:packages`, or the image tag does not exist. A database error in the api-backend logs means `DB_HOST` / `DB_USER` / `DB_PASSWORD` / `DB_NAME` are empty or the database is not on `dokploy-network`.
