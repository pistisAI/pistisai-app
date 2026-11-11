# Desktop Stabilization — Current Status (Nov 10, 2026, 19:23 EST)

## Acceptance Criteria

- [x] Desktop build stable across Linux/macOS/Windows — **IN PROGRESS**
- [ ] Known bugs documented and prioritized — **PENDING**
- [ ] Performance baseline established — **PENDING**
- [x] Ready for production release candidate — **BLOCKERS EXIST**

## Phase 1: Critical PRs (Merge)

### Status
- ✅ PR #600: Remove personal data and add personal-data guard — **MERGED**
- ⏳ PR #558: Remove private data and ship pistisai brand — **CLOSED (APPROVED, not merged)**
- ✅ PR #595: Fix CI test-desktop image — **MERGED**

**Issue:** PR #558 is CLOSED but APPROVED. It needs to be re-opened or the work cherry-picked.

## Phase 2: Flutter Build Environment
- Status: Not yet assessed
- Requires: macOS, Windows native build tools, Linux development libraries

## Phase 3: Critical Issues (Fix 5)

| # | Title | State | Priority | Notes |
|---|-------|-------|----------|-------|
| 458 | test(onboarding): fix 6 setup wizard test assertions | OPEN | HIGH | Blocks smoke tests; 6 assertions need fixes |
| 462 | [audit] Deprecated tray_manager APIs — 20 lint infos | OPEN | MEDIUM | Code quality; doesn't block functionality |
| 568 | Router: /v1/models lists models from unregistered providers | CLOSED | HIGH | Already fixed |
| 464 | [audit] Inconsistent Node.js version requirements | CLOSED | MEDIUM | Already fixed |
| 567 | Settings: add crash-report opt-in toggle | CLOSED | HIGH | Already fixed |

**Blocker:** #458 is still OPEN and blocks smoke test phase.

## Recently Completed (Nov 10, 19:00–19:23 EST)

- ✅ t_90691bea: Fixed Linux AT-SPI accessibility tree & Wayland focus instability (#616)
- ✅ t_dcd9fb1b: Documented and enforced service layer boundaries (DI) (#623)
- ✅ t_3750cdfa: Pinned all package.json versions to exact semver — removed 125 caret ^ operators (#620)
- ✅ t_5acda0ca: N+1 query detection for api-backend — identified 10 HIGH risk patterns (#621)
- ✅ t_7da03f6c: Error boundaries for async operations in api-backend (#624)

## Open Bugs (Needs Triage)

| # | Title | State | 
|---|-------|-------|
| 616 | Linux: Missing AT-SPI Accessibility Tree & Focus Instability (Wayland) | OPEN | **[Fixed in t_90691bea, awaiting commit]**
| 573 | Whitelabel builds hardcode api.pistisai.app — IAClé never loads | OPEN |
| 460 | [audit] Malformed package.json exports in supports-color | OPEN |
| 459 | [audit] Missing node_modules for backend/auth and services/tailscale-relay | OPEN |

## CI Status (Latest 5 Runs)

| Workflow | Status | Date |
|----------|--------|------|
| 🧪 CI — Test & Build Every Branch | ✅ SUCCESS | 2026-11-11 |
| CodeQL | ✅ SUCCESS | 2026-11-11 |
| Personal data guard | ✅ SUCCESS | 2026-11-11 |
| ⚡ CI Quick Gate | ✅ SUCCESS | 2026-11-11 |
| 🔢 Auto Version Bump | ❌ FAILURE | 2026-11-10 |

**Good:** Core CI passing. **Issue:** Auto version bump failed (likely no tags for auto-bump).

## Uncommitted Work in Tree

```
Modified:
  - android/app/src/main/java/io/flutter/plugins/GeneratedPluginRegistrant.java
  - linux/runner/CMakeLists.txt
  - linux/runner/my_application.cc
  - services/api-backend/eslint.config.js
  - services/api-backend/package.json

Untracked:
  - ATSPI_FIX_DOCUMENTATION.md
  - docs/architecture/service-layer/
  - linux/runner/atspi_integration.cc
  - linux/runner/atspi_integration.h
  - services/api-backend/eslint-rules/
  - test/api-backend/architecture/
  - test_atspi_integration.sh
```

**Action Needed:** Commit and push these changes to complete the recent fixes.

## Next Steps (Priority Order)

1. **COMMIT:** Push uncommitted work from recent fixes (AT-SPI, N+1 detection, DI boundaries, version pinning, error handling)
   - Affected branches: `security/input-validation-schemas-619` (current branch)
   - Creates 1–2 commits to consolidate recent work

2. **FIX #458:** Open issue — setup wizard test assertions (6 assertions)
   - Blocks: Phase 4 (Local smoke tests)
   - Effort: ~1–2 hours

3. **RECOVER PR #558:** "Remove private data and ship pistisai brand"
   - Status: CLOSED (APPROVED)
   - Option A: Re-open and rebase on latest `main`
   - Option B: Cherry-pick to new feature branch
   - Blocks: Phase 1 (Critical PRs merge)

4. **TRIAGE #573 (Whitelabel hardcoding):** IAClé splash screen blocks
   - Severity: HIGH
   - Effort: ~30 min diagnosis + 1–2 hours fix

5. **ESTABLISH PERFORMANCE BASELINE**
   - Desktop startup time (cold + warm)
   - Chat response latency
   - Memory usage (idle + active chat)
   - CPU usage (idle + active processing)
   - Baseline target: Define SLOs for "stable"

6. **AUDIT & FIX REMAINING DEPS** (#459, #460, #462)
   - Blocks: Release quality gate

## Risk Summary

- **HIGH:** PR #558 status unclear (CLOSED but needed)
- **HIGH:** Issue #458 test failures block smoke tests
- **HIGH:** Whitelabel IAClé build broken (#573) — impacts launch customer
- **MEDIUM:** Uncommitted changes need merge to solidify foundation
- **MEDIUM:** Performance baseline not yet defined (no SLOs or targets)

## Timeline Impact

- Current status: **Phase 1–2 (Nov 10–11)**
- Blocker: PR #558 + Issue #458 + whitelabel fix
- Estimated clearance: **Nov 11–12** (if parallel work on 3 blockers)
- Smoke tests can begin: **Nov 12 (after #458)**
- Full stabilization target: **Nov 24** (14 days) ✓ (current trajectory)

