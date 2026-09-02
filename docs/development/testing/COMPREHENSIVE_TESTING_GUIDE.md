# Comprehensive Testing Guide

This guide describes the current test entry points for Pistisai.

## CI gates (fast path)

Every PR to `main` runs:

| Gate | Command | What it covers |
| --- | --- | --- |
| Flutter analyze | `flutter analyze lib/` | Static analysis |
| Flutter smoke | `npm run test:ci:flutter` | Security + basic allowlist (see `scripts/ci/flutter_security_basic_tests.sh`) |
| Backend lint | `cd services/api-backend && npm run lint` | ESLint |
| Backend security | `cd services/api-backend && npm run test:ci:security` | Auth, RBAC, validation, rate limits, connector hardening |
| Linux desktop smoke | `.github/workflows/linux-integration-test.yml` | Docker desktop boot + `/health` |
| Web E2E smoke | `.github/workflows/web-e2e.yml` | Playwright splash/smoke |

Workflow triggers: **push to `main`** and **pull requests to `main`** only (no duplicate runs on feature-branch push).

## Test layout

| Path | Purpose |
| --- | --- |
| `test/smoke/` | Minimal Flutter smoke tests (app init, pump, main args) |
| `test/integration/` | Small retained integration tests (navigation, settings, evolution) |
| `test/archive/` | Legacy property/theming tests — **not in CI** |
| `test/api-backend/` | API backend Jest tests |
| `test/api-backend/security/` | Auth, session sync, cert revocation, developer bypass |
| `test/services/` | Flutter service unit tests (subset in CI allowlist) |
| `test/e2e/` | Playwright smoke specs |

## Flutter tests

```bash
flutter analyze lib/

# CI-equivalent smoke + security/basic allowlist
npm run test:ci:flutter

# Optional: full archived theming/property suite (slow)
npm run test:archive:flutter

# Single file
flutter test test/smoke/widget_test.dart
```

## Backend tests

From `services/api-backend/`:

```bash
npm run lint
npm run test:ci:security          # CI gate
npm run test:security:verbose     # all files under test/api-backend/security/
npm run test:auth                 # authentication-authorization only
npm run test:full                 # from repo root — broader Jest sweep
```

From repo root:

```bash
npm test                          # alias for test:ci:security
npm run test:full                 # all non-ignored Jest tests under test/
```

Security CI config: `services/api-backend/jest.ci-security.config.js`

## Local infrastructure tests

Requires Hermes, Ollama, and/or api-backend running locally:

```bash
./scripts/run_local_integration_tests.sh
dart test test/archive/integration/local_demo_test.dart
dart test test/archive/integration/setup_wizard_test.dart
```

Use `dart test` (not `flutter test`) for HTTP probes — `flutter test` blocks real `HttpClient`.

## Other packages

| Package | Command |
| --- | --- |
| Streaming proxy | `cd services/streaming-proxy && npm test` |
| SDK | `cd services/sdk && npm run build && npm test` |
| OpenClaw skills | `cd services/openclaw-skills/pistisai && npm test` |

## Notes

- `user-isolation.test.js` is documented historically but not present yet; user isolation is partially covered by `authentication-authorization.test.js` until a dedicated test is restored.
- Property/deployment Jest tests and `*-integration.test.js` files are excluded from default runs via `testPathIgnorePatterns` — use `npm run test:full` locally when needed.
- Archived Flutter tests live under `test/archive/` with rationale in `test/archive/README.md`.

## Related documentation

- [API Security Testing](./API_SECURITY_TESTING.md)
- [Development Workflow](../DEVELOPMENT_WORKFLOW.md)
