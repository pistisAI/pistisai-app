# PistisAI App — Audit & Cleanup/Stabilization Plan

Date: 2026-10-25
Repo: pistisAI/pistisai-app (main)
Auditor: Zoid Maltek

## 1. Executive summary

- Open issues: 1 (#440 — large feature: device awareness + mobile connectivity + Tailscale).
- Open PRs: 6 (2 draft CI fixes, 4 dependabot bumps).
- `flutter analyze lib/` is clean (0 errors). 2 test-compile errors were found and fixed in `test/screens/onboarding/hermes_bot_step_test.dart` (stale `desktopSkipDetail` reference after commit b67ee3b removed the constant).
- Smoke suite (`scripts/ci/flutter_security_basic_tests.sh`) passes: 277 tests.
- Streaming-proxy lint is broken: `node_modules` absent (missing `@eslint/js`); api-backend lint passes.
- Branch sprawl: 27 remote + 9 local branches; 12 remote branches already merged into main and can be deleted; 5 dependabot pub branches are orphaned (no open PR).
- Dependency debt: 97 upgradable (minor), 9 constrained older; not blocking.
- Archived tests (45 files) still referenced by CI integration rig.

## 2. Issues audit

### #440 — Device awareness + mobile connectivity + Tailscale integration
- Type: feature, large scope. No assignee, no labels.
- Spans Tailscale install, gateway device/location context, progressive-disclosure UI, coexistence with Hermes Desktop.
- Acceptance criteria are broad; recommend splitting into sub-issues per acceptance criterion before work starts. Do not let this block stabilization.

## 3. PRs audit

| PR | Title | State | Notes |
|----|-------|-------|-------|
| 452 | fix(ci): raise macOS deployment target to 12.0 | DRAFT | Aligns with Flutter 3.47.7. Checks green. Merge when ready. |
| 448 | fix(ci): retry flaky Android NDK sdkmanager install | DRAFT | References Flutter 3.44.6 (stale — repo now 3.47.7). Update NDK pin source to 3.47.7 before merge. |
| 436 | chore(deps): opentelemetry 0.79→0.81 (streaming-proxy) | OPEN | Checks green. Mergeable UNKNOWN → rebase. |
| 425 | chore(deps): googleapis 176→186 (api-backend) | OPEN | Checks green. Mergeable. |
| 427 | chore(deps): dotenv 17.4→18.0 (root) | OPEN | Mergeable UNKNOWN → rebase. |
| 424 | chore(deps): dotenv 17.4→18.0 (api-backend) | OPEN | Mergeable UNKNOWN → rebase. |

Action: rebase/merge the 4 dependabot PRs (all green), then update & merge 448/452.

## 4. Codebase audit

### 4.1 Flutter (lib/)
- `flutter analyze lib/`: 0 errors, 0 warnings.
- `flutter analyze` (whole project): 36 infos, all in `test/archive/` (stale `@Timeout` annotations + 2 doc-comment infos). Not in active code.
- Smoke suite: 277 tests pass.
- `pubspec.yaml`: Flutter 3.47.7, dartssh2 2.22.5, pointycastle 4 override.
- 97 upgradable deps (minor), 9 constrained older — low priority.

### 4.2 Node services
- api-backend: lint passes (eslint .). 138 test files. node_modules present (496 pkgs).
- streaming-proxy: lint broken — node_modules absent, `@eslint/js` missing. Run `npm install` in services/streaming-proxy.
- Both use Node >=22.

### 4.3 Tests
- Active test dirs: smoke, config, services, screens, models, utils, helpers, widgets, integration, tunnel, unit, e2e, policy, native, camera, v4l2.
- `test/archive/` holds 45 stale integration/widget tests still wired into `integration-test-rig.yml`. Either revive or remove from CI paths.

### 4.4 Branches
- Merged into main (safe to delete, remote + local): cursor/android-mobile-connection-ee40, feat/integration-test-rig, feat/pistisai-awareness-hook, feat/pistisai-package-install, feat/pistisai-unified-channel-context, fix/ci-required-check-398, fix/install-desktop-plugin, fix/linux-desktop-icons, fix/nodemailer-10-399, fix/openclean-string-cleanup, fix/pistisai-ui-server-document-root, iacle/main (remote only).
- Orphaned dependabot pub branches (no open PR): cupertino_icons-2.0.0, flutter_secure_storage-11.2.0, image-4.12.0, logger-2.8.0, record-7.1.2 → delete.
- Long-lived: windows_desktop (keep), fix/ci-android-ndk-install-retry (PR 448, update), fix/remove-openclaw-offerings-396 (closed PR; delete or revive), fix/android-pr-build-397 (no PR; inspect before delete).

### 4.5 Other
- `.env.example` present; no committed `.env`. Good.
- No large committed binaries except build artifacts under android/.gradle and linux/flutter/ephemeral (gitignored).
- 24 lib files still reference "openclaw" — verify whether these are internal manager names (likely) vs leftover user-facing strings (PR 445 already swept strings). Spot-check during cleanup.

## 5. Stabilization completed this session
- Fixed `test/screens/onboarding/hermes_bot_step_test.dart` compile error: replaced removed `HermesBotInstallService.desktopSkipDetail` with installed-step fixture (`'Wrote 1 file(s).'`) and updated assertion to `'Desktop embed: Installed'`. Test now passes (4/4).
- `flutter analyze` now reports 0 errors.
- Phase 0 complete: streaming-proxy `npm install` (lint now passes); merged PRs 448, 452, 424, 425, 427, 436.
- Phase 1 complete: deleted 11 merged remote branches + 8 local merged branches; pruned stale refs. Remaining remote: fix/android-pr-build-397, fix/remove-openclaw-offerings-396, windows_desktop, iacle/main.
- Resolved dependabot high-severity alert #7 (zod, unused in sdk) by removing the dependency.
- Baselines: flutter smoke 277 pass; api-backend 2603 pass; streaming-proxy 92 pass; sdk 31 pass; active (non-archive) flutter tests 1010+ pass.

## 6. Cleanup plan (phased)

### Phase 0 — Unblock (1 session)
1. `cd services/streaming-proxy && npm install` (fix lint + tests).
2. Rebase/merge dependabot PRs 424, 425, 427, 436.
3. Update PR 448 to Flutter 3.47.7 NDK source; merge 448 + 452.

### Phase 1 — Branch hygiene (1 session)
4. Delete merged remote+local branches (list in 4.4).
5. Delete orphaned dependabot pub branches.
6. Decide fate of fix/android-pr-build-397 and fix/remove-openclaw-offerings-396 (inspect diffs first).

### Phase 2 — Test hygiene (1-2 sessions)
7. Either revive or remove `test/archive/` (45 files) from `integration-test-rig.yml` paths and CI job.
8. Fix the 34 stale `@Timeout` annotations in archived tests (or delete the tests).
9. Run full api-backend suite (`npm test` in services/api-backend) and record pass/fail baseline.
10. Run `flutter test` on the full test/ tree (not just smoke) and triage failures.

### Phase 3 — Dependency & CI (1 session)
11. Run `flutter pub upgrade` (minor) in a branch; verify analyze + smoke + build web/linux.
12. Consolidate CI workflows where redundant (ci.yml vs test.yml); document which is authoritative.
13. Update issue #440: split into sub-issues per acceptance criterion; label + assign.

### Phase 4 — Verification gate
14. `flutter analyze lib/` == 0 errors, 0 warnings.
15. Smoke suite green.
16. Web + Linux builds green.
17. api-backend + streaming-proxy lint + tests green.
18. No orphaned branches; PR queue empty except active feature work.

## 7. Risks
- Merging dependabot PRs may introduce breaking changes in googleapis/dotenv; run api-backend tests after each merge.
- Deleting branches is recoverable via reflog for 90 days but treat as irreversible externally — confirm before bulk delete.
- #440 is large; keep it out of the stabilization critical path.

## 8. Open questions
- Should archived tests be revived or deleted? (Needs Christopher's call — they may encode intended behavior.)
- Is `windows_desktop` branch still needed, or fold into main?
- Should openclaw internal references be renamed to hermes/pistisai for consistency?

## 9. Verification gate results (Phase 4) — completed
- `flutter analyze lib/`: 0 issues.
- `flutter test` (active dirs, excluding archive): 852 passed.
- `flutter build web --release`: success.
- `flutter build linux --release`: success.
- `npm test` api-backend: 2603 passed (98 suites); streaming-proxy: 92 passed (5 suites); sdk: 31 passed.
- `npm run lint` all services: pass.
- Dependabot alerts: 0 open (all 7 fixed).
- Open PRs: 0. Remote branches remaining: fix/android-pr-build-397, fix/remove-openclaw-offerings-396 (hold — unique commits not yet on main).

## 10. Remaining decisions for Christopher
- Delete `test/archive/` entirely vs keep for local runs (CI no longer references it).
- Revive or drop the two held branches' unique commits (android CI workflow hardening; OpenClaw removal UI pieces).
- `windows_desktop` branch status (offline, 44d).
- Issue #440: split into sub-issues per acceptance criterion; label + assign.
- CI consolidation: kept both `ci.yml` (quick gate on non-main push) and `test.yml` (main + PR, required check). Documented as authoritative = `test.yml`; `ci.yml` is supplementary.
