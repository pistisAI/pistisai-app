# Web Deploy

Production web hosting is the image built from the repo-root [`Dockerfile.web`](../../../Dockerfile.web) and published by [`.github/workflows/deploy-web.yml`](../../../.github/workflows/deploy-web.yml). The image is run with Docker Compose on the host (`config/docker/docker-compose.web.yml`).

A second Dockerfile, [`config/docker/Dockerfile.web`](../../../config/docker/Dockerfile.web), is the compose path. It does not compile Flutter. It serves an already-built `build/web/` tree on port `8080` as a non-root user.

## What the production image does

The builder is `gmeligio/flutter-android:3.47.7` (match `environment.flutter` in `pubspec.yaml`). That image does not enable Flutter web on its own, so the Dockerfile runs `flutter config --enable-web` before `flutter build web`.

The release build passes `--no-web-resources-cdn`. The site content policy blocks the Google-hosted CanvasKit script. With the CDN build, the Flutter view never paints and the splash clears to a white page. CanvasKit must be served from this origin.

After the Flutter build, the Dockerfile reads `assets/version.json` and replaces the literal `$FLUTTER_BUILD_NUMBER` in `build/web/index.html` with `{version}.{build_number}`. The source file [`web/index.html`](../../../web/index.html) keeps the placeholder. A local `flutter build web` does not perform that replacement.

The runtime stage is `nginx:alpine`. It copies `build/web` and the repo-root [`nginx.conf`](../../../nginx.conf), listens on port 80, and healthchecks with:

```dockerfile
HEALTHCHECK --interval=5s --timeout=3s --start-period=5s --retries=5 \
  CMD wget --quiet --tries=1 --spider http://127.0.0.1/ || exit 1
```

Use `127.0.0.1`, not `localhost`. In this image `localhost` can resolve to IPv6 while nginx is listening on IPv4, so the check fails.

`.dockerignore` drops `android/`, `docs/`, `*.md`, and `pubspec.lock` from the build context. `flutter pub get` inside the image resolves from `pubspec.yaml` constraints, not from the lockfile on the developer machine.

## Cache rules

`nginx.conf` is a single server.

| Request | Policy |
| --- | --- |
| `/` and other paths that miss the rules below, including `index.html` and `*.wasm` | `Cache-Control: no-cache` |
| Exact path `/flutter_bootstrap.js` (query string ignored) | `Cache-Control: no-cache` |
| Other `.js`, `.css`, images, and fonts | 1 year, `public, immutable` |

The exact `flutter_bootstrap.js` location exists because the long-cache regex would otherwise match it. Browsers that kept an immutable copy of the old bootstrap kept loading the blocked CanvasKit URL after the image changed. The version query string on the script tag changes only when the image build substitutes `$FLUTTER_BUILD_NUMBER`.

## Pipeline

`deploy-web.yml` runs when [Auto Version Bump](../../../.github/workflows/auto-version-bump.yml) completes on `main`, or on `workflow_dispatch`.

1. **analyze** — Flutter pin from `pubspec.yaml` on `ubuntu-24.04`, `flutter pub get`, `flutter analyze lib/`. Skipped when the triggering bump workflow failed.
2. **build_and_push** — Build `Dockerfile.web` and push `ghcr.io/pistisai/pistisai-app-web:{version}` and `:latest`. `{version}` is the `version` field in `assets/version.json`. The job fails if the build action returns no digest.
3. **deploy** — Pull the published image and run it with `docker compose -f config/docker/docker-compose.web.yml up -d` on the host.

Desktop, mobile, and backend workflows start from a completed Web Deploy run. They do not start from the version bump directly. See [CI/CD Quick Reference](CI_CD_QUICK_REFERENCE.md).

### Deploy with Docker Compose

Deployment runs on the host with `docker compose -f config/docker/docker-compose.web.yml up -d`. The host must be able to pull `ghcr.io/pistisai/pistisai-app-web` (log in with `docker login ghcr.io` using a token that has `read:packages`). The compose file restarts the container and its healthcheck reports the result.

## Public check and cache purge

The job requests `https://example.com/` and `https://www.example.com/`, up to 24 times per host, 5 seconds apart. Each response must be HTTP 200, contain `Pistisai`, and must not contain `404 page not found` (the placeholder served while the container is unhealthy or unrouted).

Cloudflare purge runs with `if: always()`. It no-ops when `CLOUDFLARE_CACHE_PURGE_TOKEN` or `CF_ZONE_ID` is unset, and a failed purge does not fail the job. The nginx `no-cache` rules above are what stop browsers from pinning `flutter_bootstrap.js`. The purge is an extra flush, not the cache fix.

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

The container is not healthy or the port is not published. Check `docker compose -f config/docker/docker-compose.web.yml ps` and `docker logs` for the web container. Check the image healthcheck uses `http://127.0.0.1/`.

### Blank page after the splash

The browser loaded a CanvasKit URL on `gstatic.com`, or it is still executing an old `flutter_bootstrap.js`. Rebuild with `--no-web-resources-cdn`. Confirm `index.html` references `flutter_bootstrap.js?v=` plus the current version, and that a direct request for `/flutter_bootstrap.js` returns `Cache-Control: no-cache`.

### GHCR pull fails on the host

The host is not logged in to `ghcr.io`, or the token lacks `read:packages`. Run `docker login ghcr.io` on the host and retry `docker compose pull`.

### Web image build cannot see the lockfile or Android project

That is `.dockerignore`. Android sources are not part of the web image. Dependency resolution uses `pubspec.yaml` only.
