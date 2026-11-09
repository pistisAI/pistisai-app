# Web Deploy

Production web hosting is the image built from the repo-root [`Dockerfile.web`](../../../Dockerfile.web) and published by [`.github/workflows/deploy-web.yml`](../../../.github/workflows/deploy-web.yml). Coolify pulls that image and Traefik routes to it only after the container healthcheck passes.

A second Dockerfile, [`config/docker/Dockerfile.web`](../../../config/docker/Dockerfile.web), is the compose path. It does not compile Flutter. It serves an already-built `build/web/` tree on port `8080` as a non-root user. Do not use it to reproduce the Coolify image.

## What the production image does

The builder is `gmeligio/flutter-android:3.47.7` (match `environment.flutter` in `pubspec.yaml`). That image does not enable Flutter web on its own, so the Dockerfile runs `flutter config --enable-web` before `flutter build web`.

The release build passes `--no-web-resources-cdn`. The site content policy blocks the Google-hosted CanvasKit script. With the CDN build, the Flutter view never paints and the splash clears to a white page. CanvasKit must be served from this origin.

After the Flutter build, the Dockerfile reads `assets/version.json` and replaces the literal `$FLUTTER_BUILD_NUMBER` in `build/web/index.html` with `{version}.{build_number}`. The source file [`web/index.html`](../../../web/index.html) keeps the placeholder. A local `flutter build web` does not perform that replacement.

The runtime stage is `nginx:alpine`. It copies `build/web` and the repo-root [`nginx.conf`](../../../nginx.conf), listens on port 80, and healthchecks with:

```dockerfile
HEALTHCHECK --interval=5s --timeout=3s --start-period=5s --retries=5 \
  CMD wget --quiet --tries=1 --spider http://127.0.0.1/ || exit 1
```

Use `127.0.0.1`, not `localhost`. In this image `localhost` can resolve to IPv6 while nginx is listening on IPv4, so the check fails and Traefik keeps the container out of rotation.

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
2. **build_and_push** — Build `Dockerfile.web` and push `ghcr.io/IAClé/iacle-app-web:{version}` and `:latest`. `{version}` is the `version` field in `assets/version.json`. The job fails if the build action returns no digest.
3. **deploy_coolify** — Log the Coolify host into GHCR, trigger the deploy, wait, then check the public sites.

Desktop, mobile, and backend workflows start from a completed Web Deploy run. They do not start from the version bump directly. See [CI/CD Quick Reference](CI_CD_QUICK_REFERENCE.md).

### Coolify trigger

Required secrets: `COOLIFY_API_TOKEN`, `COOLIFY_SSH_KEY`. The host, Coolify base URL, and app UUID live in `deploy-web.yml` (`COOLIFY_URL`, `COOLIFY_APP_UUID`).

Before the deploy call, the job SSHes to the Coolify host and runs `docker login ghcr.io` with the Actions `GITHUB_TOKEN`. The image is private, so the host cannot pull it without that login. The step must set `GITHUB_TOKEN` in its own `env`. Actions does not put the token in the environment otherwise, and `set -u` fails the step.

The trigger is `POST {COOLIFY_URL}/api/v1/deploy?uuid={COOLIFY_APP_UUID}&force=true` with a bearer token. HTTP `200`, `201`, or `202` is accepted, and the body must include a deployment UUID (`deployments[0].deployment_uuid` or `deployment_uuid`).

The job then polls `GET /api/v1/deployments/{uuid}` up to 60 times, 15 seconds apart.

| Status | Result |
| --- | --- |
| `finished`, `success` | Deploy step succeeds |
| `failed`, `cancelled`, `canceled` | Job fails |
| anything else | Keep polling, then fail on timeout |

### Public check and cache purge

The job requests `https://example.com/` and `https://www.example.com/`, up to 24 times per host, 5 seconds apart. Each response must be HTTP 200, contain `IAClé`, and must not contain `404 page not found` (the Traefik placeholder while the container is unhealthy or unrouted).

Cloudflare purge runs with `if: always()`. It no-ops when `CLOUDFLARE_CACHE_PURGE_TOKEN` or `CF_ZONE_ID` is unset, and a failed purge does not fail the job. The nginx `no-cache` rules above are what stop browsers from pinning `flutter_bootstrap.js`. The purge is an extra flush, not the cache fix.

## Local checks

```bash
# Production image (compiles Flutter web)
docker build -f Dockerfile.web -t IAClé-web .

# Compose image (requires build/web first)
flutter build web --release --no-web-resources-cdn
docker build -f config/docker/Dockerfile.web -t IAClé-web-prebuilt .
```

Confirm the production image substituted the bootstrap version and answers on IPv4:

```bash
docker run --rm IAClé-web \
  grep -o 'flutter_bootstrap.js?v=[^"]*' /usr/share/nginx/html/index.html
```

The printed query value should be `{version}.{build_number}` from `assets/version.json`, not the literal `$FLUTTER_BUILD_NUMBER`.

## Troubleshooting

### Site stays on the Traefik 404

The container is not healthy, or Coolify has not attached it to the route. Check the image healthcheck uses `http://127.0.0.1/` and that the deploy job reached `finished` or `success`. A single curl during startup can still see the 404; the workflow retries for about two minutes.

### Blank page after the splash

The browser loaded a CanvasKit URL on `gstatic.com`, or it is still executing an old `flutter_bootstrap.js`. Rebuild with `--no-web-resources-cdn`. Confirm `index.html` references `flutter_bootstrap.js?v=` plus the current version, and that a direct request for `/flutter_bootstrap.js` returns `Cache-Control: no-cache`.

### GHCR pull fails on the Coolify host

The SSH `docker login` step did not run, `COOLIFY_SSH_KEY` cannot log in, or the step forgot to map `GITHUB_TOKEN` into `env`. The workflow passes that token on stdin to `docker login ghcr.io`. A missing `COOLIFY_API_TOKEN` fails earlier, before the SSH step.

### Web image build cannot see the lockfile or Android project

That is `.dockerignore`. Android sources are not part of the web image. Dependency resolution uses `pubspec.yaml` only.
