# Pistisai Docker Compose Deployment Guide

> **Current orientation**: Pistisai is agent-runtime-first and Tailscale-first. The setup wizard selects an agent runtime such as Hermes, OpenClaw, a compatible custom agent gateway, or an optional hosted agent runtime. Ollama, LM Studio, and similar model servers are support model providers, not primary app runtimes. Older WebSocket tunnel flows remain fallback references.

See [Deployment Overview](DEPLOYMENT_OVERVIEW.md) for all deployment options and [Web Deploy](../operations/cicd/WEB_DEPLOY.md) for the production image.

> **File names**: there is no `docker-compose.production.yml` and no `docker-compose.dev.yml` in this repository. The real Compose files are `docker-compose.yml` (full local stack), `docker-compose.prod.yml` (backend + monitoring) and `config/docker/docker-compose.web.yml` (production web image on the host). There is also no `deploy.sh` or script that uploads a build to a VPS.

## Production path (GitHub Actions → GHCR → host)

Production images are built and published by GitHub Actions, not by a manual upload step:

1. Push to `main` (or dispatch `.github/workflows/deploy-web.yml`). The workflow builds `Dockerfile.web`, pushes `ghcr.io/pistisai/pistisai-app-web:{version}` and `:latest`, verifies the push digest, then purges the Cloudflare zone with `CLOUDFLARE_CACHE_PURGE_TOKEN` / `CF_ZONE_ID`.
2. `.github/workflows/deploy-backend.yml` runs via `workflow_run`, building `ghcr.io/<repo>/api-backend`, `/streaming-proxy` and `/postgres` from the Dockerfiles in `config/docker/`.
3. On the host, pull the published image and start it:

   ```bash
   docker login ghcr.io   # token needs read:packages
   docker compose -f config/docker/docker-compose.web.yml pull
   docker compose -f config/docker/docker-compose.web.yml up -d
   docker compose -f config/docker/docker-compose.web.yml ps
   ```

   The host pull is currently manual — the workflow's `purge_cache` job documents this gap. If the host deploys after the purge, re-run the workflow or purge the cache again.

Do not substitute a hand-written VPS deployment procedure for this chain; see [Strict Deployment Policy](STRICT_DEPLOYMENT_POLICY.md).

## Local Compose stack

```bash
git clone https://github.com/pistisai/pistisai-app.git
cd pistisai-app
cp .env.example .env
# Edit .env with domain, database and secret values
docker compose up -d database redis api-backend
docker compose ps
docker compose logs -f api-backend
```

Services in `docker-compose.yml`: `database` (PostgreSQL, with healthcheck), `redis`, `cloudflared`, `tailscale-relay`, `webapp`, `api-backend` (healthcheck `curl --fail http://localhost:8080/health`), `postfix-mail` and `certbot`.

`docker-compose.prod.yml` is a backend/monitoring-oriented file: `api-backend`, `streaming-proxy`, `redis`, `traefik`, `prometheus`, `grafana`. It does not define an `nginx` or `certbot` service.

## Verify a deployment

```bash
# Host web container (config/docker/docker-compose.web.yml)
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

- **Image not updated after a workflow run**: the host pulls separately; run `docker compose -f config/docker/docker-compose.web.yml pull && docker compose -f config/docker/docker-compose.web.yml up -d`.
- **Cache purge failed**: check `CLOUDFLARE_CACHE_PURGE_TOKEN` and `CF_ZONE_ID` are set (see [Secrets Management](SECRETS_MANAGEMENT.md)).
- **Healthcheck fails**: use `127.0.0.1` rather than `localhost` when checking inside the web image; see [Web Deploy](../operations/cicd/WEB_DEPLOY.md).
- **Sign-in fails**: confirm the Cloudflare Access configuration; Google OAuth client IDs are not read by the app.
- **Node services fail**: use Node 26 (`.nvmrc`; service engines `>=26 <28`).

## Kubernetes alternative

For multi-user production, the repo also ships standard manifests in `config/kubernetes/base/` and `services/api-backend/k8s/`. There is no root `k8s/` directory. See [Deployment Overview](DEPLOYMENT_OVERVIEW.md) and [Self-Hosting Guide](SELF_HOSTING.md).

## Support

- GitHub Issues: https://github.com/pistisAI/pistisai-app/issues
- [Documentation index](../README.md)
