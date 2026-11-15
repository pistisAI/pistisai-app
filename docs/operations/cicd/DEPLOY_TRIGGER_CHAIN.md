# Deploy trigger chain

Chosen flow after [#681](https://github.com/pistisAI/pistisai-app/issues/681):

```text
push to main (paths-ignore: **.md, docs/**, images/**)
  -> Web Deploy
    -> Desktop Build & Release   (workflow_run)
    -> Mobile Build & Release    (workflow_run)
    -> Backend Deploy            (workflow_run)
```

- **Web Deploy** is the chain entry point. It runs on `push` to `main` (same docs/images path ignore as the test workflow) or `workflow_dispatch`.
- **Desktop**, **Mobile**, and **Backend** stay on `workflow_run` of Web Deploy (success only) plus their existing manual/tag triggers.
- **Auto Version Bump** still runs on push to `main` and opens a version-bump PR. It no longer gates deploys. Merging that PR is another push to `main`, which runs Web Deploy again with the bumped `assets/version.json`.

Manual override: `gh workflow run "🌐 Web Deploy" --ref main`.
