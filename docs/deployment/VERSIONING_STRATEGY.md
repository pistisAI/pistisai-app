# Pistisai Versioning Strategy

## Overview

Pistisai versions use semantic versioning plus a monotonic integer build number. Versions are bumped by automation on `main`, and every change reaches `main` through a pull request (`AGENTS.md`, `CONTRIBUTING.md`). There is no `master` branch in the current workflow.

Evidence: `assets/version.json`, `pubspec.yaml`, `.github/workflows/auto-version-bump.yml`, `scripts/version_bump_kind.py`, `scripts/update-all-versions.sh`, `.github/workflows/deploy-web.yml`.

## Version Format

**Format:** `MAJOR.MINOR.PATCH+<integer build_number>`

- **MAJOR.MINOR.PATCH**: semantic version (`semver.org`)
- **build_number**: an incrementing integer, **not** a timestamp

Current example (from `assets/version.json` and `pubspec.yaml`): `1.5.58+180`.

`assets/version.json` records `version`, `build_number`, `build_date`, `git_commit` and `buildTimestamp`. The `build_date` / `buildTimestamp` fields are timestamps; `build_number` is the integer shown after `+` in `pubspec.yaml`. Older revisions of this guide documented a `YYYYMMDDHHMM` build suffix — that format is not used here.

## Sources of truth

| File | Field | Meaning |
| --- | --- | --- |
| `assets/version.json` | `version` | semver, read by `deploy-web.yml` to tag the GHCR image |
| `assets/version.json` | `build_number` | incrementing integer build counter |
| `pubspec.yaml` | `version: X.Y.Z+N` | app version + build number, consumed by Flutter builds |

`version_manager.sh`, `update-all-versions.sh`, `analyze-version-bump.sh` and `version_bump_kind.py` are the version helper scripts. `update-all-versions.sh` derives a build number from `git rev-list --count HEAD`.

## How bumps happen

`.github/workflows/auto-version-bump.yml` runs on every push to `main`, on published releases, and on manual `workflow_dispatch`:

1. **Determine bump type** from the merged PR's Conventional Commit title via `scripts/version_bump_kind.py`:
   - `type!:` or a `BREAKING CHANGE:` footer → **major**
   - `feat` (any scope) → **patch** (a minor bump is a manual `workflow_dispatch` release)
   - anything else → **patch**
   - `chore(release): bump version ...` → **skip** (prevents a bump loop)
2. **Compute the new version** from `assets/version.json` on `main`; increment the selected semver component and add 1 to `build_number`.
3. **Write** the new `assets/version.json` and `pubspec.yaml` version line.
4. **Open a PR** titled `chore(release): bump version to X.Y.Z+N`, base `main`, using a GitHub App token (`BUMP_APP_ID` / `BUMP_APP_KEY`); a watcher merges it once checks pass. The workflow never pushes directly to `main`.

This replaces the old "manual increment after deployment, then push to `master`" process. No operator runs a version-manager command as part of a release.

## Release types

- **PATCH**: the default for merged PRs (`fix`, `ci`, `docs`, `test`, and `feat` under the current automation rule).
- **MINOR**: available through a manual `workflow_dispatch` with `bump: minor`.
- **MAJOR**: a breaking change (`!` or `BREAKING CHANGE:` footer).

## Deploy integration

`deploy-web.yml` reads `.version` from `assets/version.json` and publishes `ghcr.io/pistisai/pistisai-app-web:{version}` plus `:latest`. `deploy-backend.yml` reads the same version and tags backend images with `v{version}` and `build-{version}-{short_sha}`. The production web build substitutes `{version}.{build_number}` into `build/web/index.html` (see [Web Deploy](../operations/cicd/WEB_DEPLOY.md)).

A hotfix follows the same path: branch from `main`, open a PR, merge, let the automation bump and deploy. There is no separate expedited "6-phase" or VPS deployment process.

## Version history examples

```
1.5.58+180   ← current release (semver 1.5.58, build 180)
1.5.57+179   ← previous patch release
1.6.0+181    ← example manual MINOR bump
2.0.0+200    ← example MAJOR (breaking-change) bump
```

## Best Practices

1. Use Conventional Commit titles: they determine the bump size.
2. Do not hand-edit `assets/version.json` or the `pubspec.yaml` version line outside the bump PR.
3. Do not reintroduce timestamp suffixes or a `master` branch.
4. Never commit version secrets; keep `BUMP_APP_ID` / `BUMP_APP_KEY` in GitHub Actions secrets (see [Secrets Management](SECRETS_MANAGEMENT.md)).
