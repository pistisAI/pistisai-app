# Pistisai Agent Operations (Paperclip-managed agents)

This file supplements `AGENTS.md` (the repo's authoritative guide). Read BOTH files.
This file governs how you operate as a Paperclip agent on this host.

## Your environment
- You are a Paperclip **process adapter** agent running on the PistisAI dev host (Linux/CachyOS).
- Your working copy is at `/home/rightguy/pistisai-app` (repo: `git@github.com:pistisAI/pistisai-app.git`).
- Git push uses SSH (`~/.ssh/id_ed25519`, IdentitiesOnly). It is non-interactive. PUSH IS ALLOWED.
- The `pistisAI` GitHub org **blocks the local `gh` CLI fine-grained token for REST API** (issue/PR/webhook calls).
  - DO NOT rely on `gh api`, `gh issue`, `gh pr`, or `gh auth` for write/read of the repo's issues/PRs. They return 403.
  - You MAY use `git` (clone/fetch/push/branch) over SSH — that path works.
  - Public read-only issue/PR data is reachable via curl to `https://api.github.com/repos/pistisAI/pistisai-app/...` without a token.

## How to get work
- Your work source of truth is the **Paperclip board** (tasks/issues assigned to you here) AND the
  repo's GitHub issue #39 "Paperclip AI — public launch" (read via the public API above, or via the
  board task that mirrors it).
- Christopher is the sole owner. Per `AGENTS.md`: **push directly to `main`** unless a branch is explicitly requested.
  Use branch `<role>/<change>` only for experimental changes that might break the build.
- When the board inbox is empty but GitHub issue #39 has open sub-items, pick the next concrete
  deliverable and execute it, then push to `main` and report on the board.

## Anti-idle directive (CRITICAL)
- You run on a 30s heartbeat. On every heartbeat: check the board inbox, check issue #39's open items,
  and if there is ANY unfinished, concrete, repo-relevant work, EXECUTE it and push. Do not report "no
  explicit task" and stop. If the board is empty, advance issue #39 (public launch) by shipping a
  tangible artifact (docs, config, asset, or code) to `main`.
- Tangible output required every cycle: a commit on `main` (or a clearly-named branch) that moves the
  project forward. Commentary without artifacts is failure.

## Public launch (issue #39) — suggested first deliverables
Issue #39 is "Paperclip AI — public launch." High-signal, concrete starters you can ship now:
1. A `README.md` public-launch section / one-liner + quick-start that matches the product (local-first
   AI agent companion, desktop + web, Tailscale-secured).
2. A `docs/LAUNCH.md` with positioning, supported runtimes, and setup steps.
3. Ensure `SECURITY.md` and `DEPLOYMENT.md` are current and accurate.
4. Verify `flutter analyze` and root `npm test` pass on `main`; fix trivial breakages and push.

## Reporting
- After each push, post a board comment / update the assigned task with what landed (commit SHA, files).
- Keep the board and the repo state aligned.
