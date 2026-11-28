# Pistisai Docker Compose Deployment Guide

> **Current orientation**: Pistisai is agent-runtime-first and Tailscale-first. The setup wizard selects an agent runtime such as Hermes, OpenClaw, a compatible custom agent gateway, or an optional hosted agent runtime. Ollama, LM Studio, and similar model servers are support model providers, not primary app runtimes. Older WebSocket tunnel flows remain fallback references.

See [Deployment Overview](DEPLOYMENT_OVERVIEW.md) for all deployment options and [Web Deploy](../operations/cicd/WEB_DEPLOY.md) for the production image.

> **File names**: there is no `docker-compose.production.yml` and no `docker-compose.dev.yml` in this repository. The hosted backend file is `config/docker/docker-compose.dokploy-backend.yml` ([Dokploy](DOKPLOY.md)). `docker-compose.yml` is the local stack. `docker-compose.prod.yml` and `config/docker/docker-compose.web.yml` are not for Dokploy (each file says so at the top). There is no script that uploads a build over SSH.

## Production path (GitHub Actions → GHCR → Dokploy)

The desktop app is the hub. Hosted web and API run on Dokploy. Images are built and published by GitHub Actions:

1. Push to `main` (or dispatch `.github/workflows/deploy-web.yml`). The workflow builds `Dockerfile.web` and pushes `ghcr.io/pistisai/pistisai-app-web:{version}` and `:latest`. `{version}` is the `version` field in `assets/version.json`.
2. The `deploy_dokploy` job calls `scripts/ci/trigger_dokploy_deploy.sh` ([#1056](https://github.com/pistisAI/pistisai-app/issues/1056)) with `DOKPLOY_WEBHOOK_URL`. Dokploy pulls `ghcr.io/pistisai/pistisai-app-web:latest` into an Application on container port 80. The job runs before the full-zone Cloudflare purge (`CLOUDFLARE_CACHE_PURGE_TOKEN` / `CF_ZONE_ID`).
3. `.github/workflows/deploy-backend.yml` runs via `workflow_run` and pushes `ghcr.io/pistisai/pistisai-app/api-backend`, `/streaming-proxy`, and `/postgres`. Its `deploy_dokploy` job uses `DOKPLOY_BACKEND_WEBHOOK_URL`. Dokploy runs [`config/docker/docker-compose.dokploy-backend.yml`](../../config/docker/docker-compose.dokploy-backend.yml) (api-backend and streaming-proxy only).

Dokploy needs a `ghcr.io` credential with `read:packages`. Set the repository variable `DOKPLOY_REQUIRED` to `true` when a missing webhook must fail the job. Details, rollback via `IMAGE_TAG`, and the optional API secrets are in [Dokploy](DOKPLOY.md).

Do not deploy over SSH. See [Strict Deployment Policy](STRICT_DEPLOYMENT_POLICY.md).

## Local Compose stack

```bash
git clone https://github.com/pistisai/pistisai-app.git
cd pistisai-app
cp .env.example .env
# Edit .env with domain, database and secret values
docker compose up -d database api-backend
docker compose ps
docker compose logs -f api-backend
```

Services in `docker-compose.yml`: `database` (PostgreSQL, with healthcheck), `redis` (defined, unused by the API and streaming proxy), `cloudflared`, `tailscale-relay`, `webapp`, `api-backend` (healthcheck `curl --fail http://localhost:8080/health`), `postfix-mail` and `certbot`.

`docker-compose.prod.yml` is a legacy stack, not the Dokploy file: `api-backend`, `streaming-proxy`, `redis`, `traefik`, `prometheus`, `grafana`. It does not define an `nginx` or `certbot` service. The header of the file says it is not for Dokploy.

## Verify a local compose stack

Hosted checks are in [Dokploy](DOKPLOY.md). These commands are for the local Compose files only. `config/docker/docker-compose.web.yml` is not the Dokploy Application.

```bash
# Local web compose file (not Dokploy)
docker compose -f config/docker/docker-compose.web.yml ps
curl -f http://localhost/health

# Root compose services
docker compose ps
curl --fail http://localhost:8080/health
```

The `config/docker/docker-compose.web.yml` healthcheck is `curl -f http://localhost/health`. The nginx config uses `no-cache` for `index.html`, `flutter_bootstrap.js` and other HTML; see [Web Deploy](../operations/cicd/WEB_DEPLOY.md) before changing cache rules.

## Authentication

Sign-in uses Cloudflare Access for the free tunnel path (`CF_ACCESS_TEAM_DOMAIN`, `CF_ACCESS_AUD`), with a JWT returned on the callback and validated by `services/api-backend/middleware/auth.js`. The streaming-proxy image runs `proxy-server.js`, which validates no token itself (`services/streaming-proxy/src/middleware/cloudflare-access-validator.ts` is not run by that image), so Cloudflare Access must sit in front of its route. Local-only use needs no sign-in. See [Authentication Quick Reference](../development/AUTHENTICATION_QUICK_REFERENCE.md), not the old Google OAuth guide.

## Management commands

Replace `-f docker-compose.production.yml` in older notes with the actual file you are running:

```bash
# Logs
docker compose logs -f api-backend
docker compose logs -f webapp

# Restart
docker compose restart api-backend

# Stop
docker compose down

# Update local stack
git pull --ff-only
docker compose pull
docker compose up -d
```

## Database backup

```bash
docker compose exec -T database pg_dump -U appuser Pistisai > backup_$(date +%Y%m%d).sql
docker compose exec -T database psql -U appuser -d Pistisai < backup_file.sql
```

Adjust the user/database to match your `.env` settings. For production, back up on the host and store the dump outside the Compose project.

## Troubleshooting

- **Image not updated after a workflow run**: check the `deploy_dokploy` job and the Dokploy service logs. The webhook secrets are `DOKPLOY_WEBHOOK_URL` (web) and `DOKPLOY_BACKEND_WEBHOOK_URL` (backend). A GHCR pull error means the Dokploy registry credential lacks `read:packages`. See [Dokploy](DOKPLOY.md).
- **Cache purge failed**: check `CLOUDFLARE_CACHE_PURGE_TOKEN` and `CF_ZONE_ID` are set (see [Secrets Management](SECRETS_MANAGEMENT.md)).
- **Healthcheck fails**: use `127.0.0.1` rather than `localhost` when checking inside the web image; see [Web Deploy](../operations/cicd/WEB_DEPLOY.md).
- **Sign-in fails**: confirm the Cloudflare Access configuration; Google OAuth client IDs are not read by the app.
- **Node services fail**: use Node 26 (`.nvmrc`; service engines `>=26 <28`).

## Kubernetes (legacy, unmaintained)

Manifests in `config/kubernetes/base/` and `services/api-backend/k8s/` are legacy and unmaintained. There is no root `k8s/` directory, and GitHub Actions does not apply them. Hosted deploys use [Dokploy](DOKPLOY.md). See [Deployment Overview](DEPLOYMENT_OVERVIEW.md).

## Support

- GitHub Issues: https://github.com/pistisAI/pistisai-app/issues
- [Documentation index](../README.md)
