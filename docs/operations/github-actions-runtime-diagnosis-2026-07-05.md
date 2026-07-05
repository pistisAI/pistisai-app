# PAP-32 GitHub Actions Runtime Diagnosis
Date: 2026-07-05
Owners: CTO / Christopher or GitHub org admin for unblock

## Blocker
GitHub Actions startup/runtime issue preventing CI/Deploy/E2E workflows from starting on `pistisAI/pistisai-app`.

## Observed Evidence
- Repo Actions permissions: `allowed_actions: selected`
- Workflows active in `.github/workflows`: `ci.yml`, `test.yml`, `build-desktop.yml`, `build-mobile.yml`, `deploy-backend.yml`, `deploy-web.yml`, `web-e2e.yml`
- CodeQL succeeds, so webhook delivery/repo visibility are not fully broken
- Multiple workflow runs completed with `startup_failure` and `jobs: []`
- One probe workflow run started one job; adjacent runs still failed at startup
- Webhook endpoint is configured: `https://right-pc.tail5d7400.ts.net/webhooks`; runtime events may also be subject to selected-actions/runtime policy

## Most Likely Cause
Org/repo GitHub Actions policy or effective permissions block workflow/job startup. In public repos with `allowed_actions: selected`, actions and reusable workflows must be explicitly allowed; mismatch can silently prevent job creation and show `jobs: []`.

## Required Unblock Action
Christopher or GitHub org/repo admin should:
1. Inspect repo Actions settings: Settings → Actions → General → Allow actions and reusable workflows
2. If `selected`, allow required actions/workflows or switch to `all` for the duration of the launch readiness check
3. Review whether a GitHub Actions suspension, selected-actions enforcement policy, or billing/runner throttle applies
4. Rerun workflow run IDs `28744430702` and `28744431105` only after the above is corrected

## Why Repo Changes Alone Will Not Fix It
This is a platform/runtime/policy state on the GitHub side. No branch commit, revert, or workflow file change is the next move until the org/repo Actions permissions are corrected.

## Launch Readiness Note for GH #39
Do not declare public launch ready from the artifact side. The repo-side baseline is present, but CI/Deploy/E2E runtime is not green and the failure mode is external to the repo.
