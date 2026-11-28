# Deploy trigger chain

Chosen flow after [#681](https://github.com/pistisAI/pistisai-app/issues/681):

```text
push to main (paths-ignore: **.md, docs/**, images/**)
  -> Web Deploy
       build image, deploy_dokploy (Dokploy pulls), purge Cloudflare
    -> Desktop Build & Release   (workflow_run)
    -> Mobile Build & Release    (workflow_run)
    -> Backend Deploy            (workflow_run)
         build images, deploy_dokploy (Dokploy pulls), purge Cloudflare
```

- **Web Deploy** is the chain entry point. It runs on `push` to `main` (same docs/images path ignore as the test workflow) or `workflow_dispatch`.
- **Desktop**, **Mobile**, and **Backend** stay on `workflow_run` of Web Deploy (success only) plus their existing manual/tag triggers.
- **Dokploy** is the hosted runtime. `deploy_dokploy` in `deploy-web.yml` and `deploy-backend.yml` calls `scripts/ci/trigger_dokploy_deploy.sh` ([#1056](https://github.com/pistisAI/pistisai-app/issues/1056)) after the image push and before the zone purge. Secrets and the `DOKPLOY_REQUIRED` variable are in [Dokploy](../../deployment/DOKPLOY.md). The desktop app remains the hub.
- **Auto Version Bump** still runs on push to `main` and opens a version-bump PR. It no longer gates deploys. Merging that PR is another push to `main`, which runs Web Deploy again with the bumped `assets/version.json`.

Manual override: `gh workflow run "🌐 Web Deploy" --ref main`.
