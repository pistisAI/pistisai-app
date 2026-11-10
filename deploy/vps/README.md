# VPS web deploy

Manual deploys are prohibited. The web app reaches the VPS only through
`.github/workflows/deploy-web.yml`.

- The workflow builds `Dockerfile.web` (brand from the repository), checks the
  image (brand title, `no-cache` headers, `?v=<hash>` cache-busting), streams it
  with `docker save` over SSH, purges the Cloudflare zone and verifies the live
  site serves the new `main.dart.js`.
- On the VPS, user `ghdeploy` accepts one key per repository. Each key is pinned
  with `restrict,command="/usr/local/sbin/gha-web-deploy <app>"`, so it can only
  load `<app>-web:gha-<sha>` and swap the `<app>-web` container (`iacle` on
  127.0.0.1:8081, `pistisai` on 127.0.0.1:8070). A failed health check rolls back
  to `<app>-web-prev`.
- Repository secrets: `WEB_DEPLOY_SSH_KEY`, `WEB_DEPLOY_KNOWN_HOSTS`,
  `WEB_DEPLOY_HOST`, `CLOUDFLARE_CACHE_PURGE_TOKEN`, `CF_ZONE_ID`. A missing
  secret fails the job.
