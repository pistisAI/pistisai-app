# PistisAI Desktop Stabilization Plan

**Status:** Feature Freeze — Stabilize desktop (Linux/macOS/Windows) before web/mobile.

**Goal:** Ship a working desktop app locally with all current features, validated, tested, and production-ready.

---

## Executive Summary

PistisAI has grown to **313 Dart files**, **110 test files**, and **9,812 JavaScript lines** across backend services. Desktop support exists for **Linux, macOS, and Windows**, but has not been systematically stabilized. This plan:

1. **Freeze features** — lock the current state, no new features until desktop is solid.
2. **Fix critical blockers** — resolve 15+ known desktop/CI issues.
3. **Test desktop locally** — run the app on Linux/macOS/Windows, validate Hermes hub integration.
4. **Pass all tests** — unit, integration, and manual smoke tests on desktop.
5. **Ship** — merge to main when stable, tag as release-ready.

---

## Phase 1: Unblock CI & Clean Up (Nov 10–12)

### 1.1 Merge Critical PRs

| PR | Status | Action | Deadline |
|----|--------|--------|----------|
| #600 | Test failing (CSP regex fixed) | ✅ Merge when CI passes | Nov 10 |
| #558 | All CI passing | ✅ Merge | Nov 10 |
| #595 | Desktop CI broken | ✓ Review + merge | Nov 10 |
| #599 | Web cache headers | ✓ Defer to Web phase | Nov 15 |

### 1.2 Fix Immediate CI Failures

**Issue: `🏷️ White-label build has no upstream hosts` (PR #600)**
- **Root cause:** `tool/brand_emit.dart` regex didn't match CSP line structure.
- **Fix applied:** Use `replaceFirstMapped` to properly capture and replace brand hosts.
- **Verify:** Run `bash tool/brand.sh example && flutter build web --release --dart-define=BRAND=example && bash tool/brand_leak_check.sh build/web`
- **Action:** Test locally once Flutter is available.

**Issue: Desktop CI uses upstream Pistisai brand instead of fork brand (PR #595)**
- **Root cause:** `Dockerfile.test-desktop` bakes pistisai brand; should bake the fork's brand.
- **Impact:** Test-desktop image doesn't match the app's actual brand.
- **Fix:** Update Dockerfile.test-desktop to use the fork's brand config.
- **Status:** PR #595 is open.

---

## Phase 2: Desktop Build Environment Setup (Nov 12–14)

### 2.1 Establish Build Pipeline

**Environment:**
- Host: Linux (Fedora 45)
- Distrobox pistisai-dev: Exists, but Flutter/Dart NOT installed
- Decision: Install Flutter on host or in distrobox?

**Recommendation:** Install on host (cleaner, faster CI).

```bash
# Flutter 3.47.9 (from pubspec.yaml)
# Installation: https://flutter.dev/docs/get-started/install/linux
# Verify: flutter doctor
```

### 2.2 Verify Build Success

**Linux desktop:**
```bash
cd /var/mnt/DATA/dev/projects/pistisai-app
flutter pub get
flutter build linux --release
# Expected: build/linux/x64/release/bundle/pistisai
```

**macOS (skip locally, CI will verify):** `flutter build macos --release`

**Windows (skip locally, CI will verify):** `flutter build windows --release`

### 2.3 Check for Missing Dependencies

Run:
```bash
flutter analyze
```

Expected: 0 errors, <10 warnings (mostly deprecated APIs).

---

## Phase 3: Critical Issue Triage & Fix (Nov 14–18)

### 3.1 Desktop-Blocking Issues

| Issue | Component | Priority | Est. Fix Time | Assignee |
|-------|-----------|----------|---------------|----------|
| #458 | Setup wizard tests broken | **P0** | 2 hours | Fable/Claude |
| #462 | Deprecated tray_manager APIs (20 lints) | **P1** | 3 hours | Fable/Claude |
| #568 | Router /v1/models unregistered providers | **P1** | 2 hours | Backend review |
| #567 | Crash-report opt-in toggle missing | **P2** | 1 hour | Settings UI |
| #569 | TTS fallback on Windows (USERPROFILE) | **P2** | 1 hour | Platform-specific |

### 3.2 Backend Service Stability

| Service | Issue | Status |
|---------|-------|--------|
| api-backend | Node.js version inconsistency (#464) | Open — should be 26 LTS |
| auth | Missing node_modules | Open — needs setup/CI inclusion |
| streaming-proxy | Missing eslint config | Open — needs linting |
| tailscale-relay | Missing node_modules & lint | Open — needs setup/CI inclusion |

**Action:** Resolve Node.js version to 26 LTS across all services, update Dockerfiles and package.json files.

### 3.3 Test Coverage Gaps

**Setup Wizard Tests (Issue #458):**
- 6 assertions broken in `test/services/onboarding/setup_wizard_service_test.dart`
- Must pass before desktop ship (onboarding is critical path).

**Hermes Integration Tests:**
- 25+ tests in `test/services/hermes/` — verify they pass locally.
- Check for flaky tests or mock mismatches.

**Router Tests (Issue #568):**
- `/v1/models` endpoint should filter to registered providers only.
- Add test case: unregistered provider returns 400, not 200.

---

## Phase 4: Local Desktop Validation (Nov 18–20)

### 4.1 Build & Run Desktop App

**Linux:**
```bash
cd /var/mnt/DATA/dev/projects/pistisai-app
flutter run -d linux
# Or: ./build/linux/x64/release/bundle/pistisai
```

**Expected:**
- App window appears
- No crashes on startup
- Logs show clean initialization

### 4.2 Smoke Test Checklist

- [ ] **Hermes Connection:** Local hub connects successfully
  - [ ] Detect local Hermes instance
  - [ ] Fetch and display sessions
  - [ ] Send a test message, receive reply
- [ ] **UI/UX:**
  - [ ] Main chat screen loads
  - [ ] Settings screen accessible
  - [ ] Onboarding wizard works (fresh start)
  - [ ] Tray icon visible (Linux: check system tray)
- [ ] **Data Persistence:**
  - [ ] Settings persist across restart
  - [ ] Chat history saved locally
  - [ ] No data loss on app close
- [ ] **Crash Reporting:**
  - [ ] Opt-in toggle visible in settings
  - [ ] Crash reports sent when enabled
  - [ ] No forced reporting (respects toggle)
- [ ] **Logs & Diagnostics:**
  - [ ] `flutter logs` shows no ERROR lines
  - [ ] Sentry integration working (if enabled)
  - [ ] Platform-specific logs clean (Linux: journalctl, macOS: Console, Windows: Event Viewer)

### 4.3 Device Awareness Test

**Verify desktop sees itself as primary device:**
```
Hub → Primary desktop running locally ✓
Desktop → Sessions, agents, config available ✓
Routing → Web/mobile connections route through desktop ✓
```

---

## Phase 5: Integration Testing (Nov 20–22)

### 5.1 End-to-End Test Scenarios

**Scenario 1: Fresh Install → First Chat**
1. Start app on clean system (first run)
2. Onboarding: Detect local Hermes
3. Home screen: Show main chat
4. Send: "Hello world"
5. Verify: Message appears in chat, Hermes processes it

**Scenario 2: Multi-Device Routing**
1. Start desktop (primary)
2. Connect web client (secondary)
3. Send message from web → received on desktop ✓
4. Send message from desktop → received on web ✓
5. Routing gateway shows both devices ✓

**Scenario 3: Persistence**
1. Close app
2. Reopen app
3. Verify: Previous chat history intact, settings preserved

### 5.2 Platform-Specific Tests

**Linux:**
- [ ] System tray integration
- [ ] Desktop file (.desktop) launches app correctly
- [ ] Metadata (AppStream) is correct

**macOS (CI test):**
- [ ] Code signing (if required)
- [ ] Notarization ready
- [ ] App store entitlements

**Windows (CI test):**
- [ ] MSI installer works
- [ ] Taskbar icon visible
- [ ] System PATH does not interfere

---

## Phase 6: Pre-Release Checks (Nov 22–23)

### 6.1 Code Quality

```bash
flutter analyze          # Must pass (0 errors)
flutter test            # All unit tests pass
```

### 6.2 Performance

- [ ] Startup time < 3 seconds
- [ ] Memory footprint < 200 MB at idle
- [ ] CPU usage < 5% at rest

### 6.3 Documentation

- [ ] README updated with desktop build instructions
- [ ] AGENTS.md reflects current architecture
- [ ] SPEC.md aligns with implemented features

### 6.4 Release Artifacts

- [ ] Linux: `.tar.gz` with binary + AppStream metadata
- [ ] macOS: `.dmg` or `.app` bundle
- [ ] Windows: `.msi` installer

---

## Phase 7: Ship & Tag (Nov 24)

### 7.1 Final Merge

1. Merge remaining PRs (#600, #558, #595, platform-specific fixes)
2. Create release branch: `release/desktop-v1.0.0`
3. Tag: `v1.0.0-desktop`

### 7.2 Announce

- [ ] GitHub release notes (features, fixes, known limitations)
- [ ] Desktop app is now stable for production use
- [ ] Web/mobile work scheduled for Phase 2

---

## Known Limitations (To Address in Phase 2+)

| Limitation | Impact | When |
|------------|--------|------|
| No web app on desktop | Users can't test web UI locally | Post-desktop, Phase 2 |
| No mobile routing | Mobile clients not supported yet | Phase 3 |
| Manual deployment | CI doesn't auto-publish builds | Post-ship, infra work |
| macOS code signing | Not automated | Post-ship, team decision |

---

## Resource Requirements

| Resource | Status | Owner |
|----------|--------|-------|
| Flutter environment | Needs setup on host | Zoid / Infra |
| Desktop CI runners | Exist (.github/workflows) | CI maintainer |
| Testing devices | Linux available; macOS/Win via CI | Team |
| Release infrastructure | Missing; manual for now | Post-ship |

---

## Timeline

- **Nov 10–12:** Merge PRs, fix CSP & white-label tests
- **Nov 12–14:** Flutter setup & build verification
- **Nov 14–18:** Fix 5 critical issues, run tests
- **Nov 18–20:** Local smoke tests, UI validation
- **Nov 20–22:** E2E scenarios, multi-device routing
- **Nov 22–23:** Code quality, perf, release prep
- **Nov 24:** Ship & tag v1.0.0-desktop

---

## Success Criteria

✅ **Definition of Done:**

1. All Dart/Flutter tests pass (unit + integration)
2. All backend service tests pass (Node.js)
3. Desktop app builds and runs on Linux, macOS, Windows
4. Smoke test suite passes (startup, chat, settings, persistence)
5. No open P0 issues
6. Logs clean (no ERROR lines)
7. Release artifacts created and verified
8. GitHub release published with notes

---

## Next Steps

1. **Immediately (Nov 10):** Assign Phase 1 PRs to reviewers, merge when CI passes.
2. **By Nov 12:** Set up Flutter on host, verify builds.
3. **By Nov 14:** Assign critical issues to Fable/Claude, start fixing.
4. **By Nov 18:** Run local desktop smoke tests.
5. **By Nov 24:** Ship v1.0.0-desktop.

---

**Created:** Nov 10, 2026  
**Owner:** Zoid Maltek  
**Status:** Active (Phase 1)
