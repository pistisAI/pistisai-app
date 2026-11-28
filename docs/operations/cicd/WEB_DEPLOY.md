# Web Deploy

Production web hosting is the image built from the repo-root [`Dockerfile.web`](../../../Dockerfile.web) and published by [`.github/workflows/deploy-web.yml`](../../../.github/workflows/deploy-web.yml). Dokploy runs it as an Application: `ghcr.io/pistisai/pistisai-app-web:latest`, container port 80. [`config/docker/docker-compose.web.yml`](../../../config/docker/docker-compose.web.yml) is not that service. See [Dokploy](../../deployment/DOKPLOY.md).

A second Dockerfile, [`config/docker/Dockerfile.web`](../../../config/docker/Dockerfile.web), is the compose path. It does not compile Flutter. It serves an already-built `build/web/` tree on port `8080` as a non-root user.

## What the production image does

The builder is `gmeligio/flutter-android:3.47.9` (match `environment.flutter` in `pubspec.yaml`). That image does not enable Flutter web on its own, so the Dockerfile runs `flutter config --enable-web` before `flutter build web`.

The release build passes `--no-web-resources-cdn`. The site content policy blocks the Google-hosted CanvasKit script. With the CDN build, the Flutter view never paints and the splash clears to a white page. CanvasKit must be served from this origin.

After the Flutter build, the Dockerfile reads `assets/version.json` and replaces the literal `$FLUTTER_BUILD_NUMBER` in `build/web/index.html` with `{version}.{build_number}`. The source file [`web/index.html`](../../../web/index.html) keeps the placeholder. A local `flutter build web` does not perform that replacement.

The runtime stage is `nginx:alpine`. It copies `build/web` and the repo-root [`nginx.conf`](../../../nginx.conf), listens on port 80, and healthchecks with:

```dockerfile
HEALTHCHECK --interval=5s --timeout=3s --start-period=5s --retries=5 \
  CMD wget --quiet --tries=1 --spider http://127.0.0.1/ || exit 1
```

Use `127.0.0.1`, not `localhost`. In this image `localhost` can resolve to IPv6 while nginx is listening on IPv4, so the check fails.

`.dockerignore` drops `android/`, `docs/`, `*.md`, `test/`, `coverage/`, `.github/` and build artifacts from the build context. It does **not** drop `pubspec.lock`: the lockfile is present in the context, and `flutter pub get` inside the image resolves from `pubspec.lock` plus `pubspec.yaml`.

## Cache rules

`nginx.conf` is a single server.

| Request | Policy |
| --- | --- |
| `/` and other paths that miss the rules below, including `index.html` and `*.wasm` | `Cache-Control: no-cache` |
| Exact path `/flutter_bootstrap.js` (query string ignored) | `Cache-Control: no-cache` |
| Other `.js`, `.css`, images, and fonts | 1 year, `public, immutable` |

The exact `flutter_bootstrap.js` location exists because the long-cache regex would otherwise match it. Browsers that kept an immutable copy of the old bootstrap kept loading the blocked CanvasKit URL after the image changed. The version query string on the script tag changes only when the image build substitutes `$FLUTTER_BUILD_NUMBER`.

## Pipeline

`deploy-web.yml` runs on push to `main` (ignoring docs/markdown/image-only changes) or on `workflow_dispatch`. See [Deploy trigger chain](DEPLOY_TRIGGER_CHAIN.md).

1. **analyze** — Flutter pin from `pubspec.yaml` on `ubuntu-24.04`, `flutter pub get`, `flutter analyze lib/`.
2. **build_and_push** — Build `Dockerfile.web` and push `ghcr.io/pistisai/pistisai-app-web:{version}` and `:latest`. `{version}` is the `version` field in `assets/version.json`. The job fails if the build action returns no digest.
3. **deploy_dokploy** — Calls `scripts/ci/trigger_dokploy_deploy.sh` ([#1056](https://github.com/pistisAI/pistisai-app/issues/1056)) with `DOKPLOY_WEBHOOK_URL` so Dokploy pulls the new image. Optional confirmation uses `DOKPLOY_API_URL`, `DOKPLOY_API_KEY`, and `DOKPLOY_WEB_APPLICATION_ID`. The repository variable `DOKPLOY_REQUIRED=true` fails the job when the webhook secret is missing; otherwise the trigger is skipped. This page documents that job and does not edit the workflow.
4. **purge_cache** — Full-zone Cloudflare purge after Dokploy has been asked to pull (deploy fails if purge fails).

Desktop, mobile, and backend workflows start from a completed Web Deploy run. See [CI/CD Quick Reference](CI_CD_QUICK_REFERENCE.md).

### Dokploy Application

Dokploy runs `ghcr.io/pistisai/pistisai-app-web:latest` as an Application on container port 80. Add a GHCR registry credential with `read:packages` in Dokploy. Attach the public hostname in Dokploy's Domains tab. Dokploy's Traefik routes the request. Do not publish a host port.

`config/docker/docker-compose.web.yml` is a separate Compose file for a prebuilt `build/web` tree. It is not the Dokploy Application. The header of that file says so.

## Public check and cache purge

The workflow publishes the image and asks Dokploy to pull it. Verify the site after Dokploy reports the Application healthy. See [Dokploy](../../deployment/DOKPLOY.md).

The `purge_cache` job purges the whole Cloudflare zone (`purge_everything`). The job, and so the deploy, fails if `CLOUDFLARE_CACHE_PURGE_TOKEN` or `CF_ZONE_ID` is unset or Cloudflare does not answer `success`. The `deploy_dokploy` job runs before that purge (#1056) so the zone is not flushed while Dokploy is still serving the previous image. The nginx `no-cache` rules above are what stop browsers from pinning `flutter_bootstrap.js`. The purge is an extra flush, not the cache fix.

## Local checks

```bash
# Production image (compiles Flutter web)
docker build -f Dockerfile.web -t Pistisai-web .

# Compose image (requires build/web first)
flutter build web --release --no-web-resources-cdn
docker build -f config/docker/Dockerfile.web -t Pistisai-web-prebuilt .
```

Confirm the production image substituted the bootstrap version and answers on IPv4:

```bash
docker run --rm Pistisai-web \
  grep -o 'flutter_bootstrap.js?v=[^"]*' /usr/share/nginx/html/index.html
```

The printed query value should be `{version}.{build_number}` from `assets/version.json`, not the literal `$FLUTTER_BUILD_NUMBER`.

## Troubleshooting

### Site does not respond after deploy

The Dokploy Application is not healthy, or the domain is not attached to port 80. Check the Application logs in Dokploy. The image healthcheck uses `http://127.0.0.1/`.

### Blank page after the splash

The browser loaded a CanvasKit URL on `gstatic.com`, or it is still executing an old `flutter_bootstrap.js`. Rebuild with `--no-web-resources-cdn`. Confirm `index.html` references `flutter_bootstrap.js?v=` plus the current version, and that a direct request for `/flutter_bootstrap.js` returns `Cache-Control: no-cache`.

### GHCR pull fails on the host

The Dokploy registry credential for `ghcr.io` is missing or the token lacks `read:packages`. Update that credential and redeploy the Application.

### Web image build cannot see the Android project

That is `.dockerignore`. Android sources are deliberately not part of the web image; `pubspec.lock` is still included and used by `flutter pub get`.
