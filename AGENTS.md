# Pistisai — Agent Guide

Flutter desktop/web app + Node.js backend services: local-first companion layer for agent runtimes (Hermes primary test path, OpenClaw Gateway, compatible gateways). Ollama/LM Studio are support model providers for app-owned features (e.g. embeddings) — not primary runtimes unless wrapped by an agent runtime.

## Layout (service → port / contract)

- `lib/main.dart`, `lib/di/locator.dart` — app entry, two-phase DI: `setupCoreServices()` → `setupAuthenticatedServices()`
- `lib/services/router_server.dart` — embedded OpenAI-compatible router, defaults to port `1337`
- `lib/database/drift_local_brain.dart` — Drift/SQLite local brain (generated `.g.dart`, DO NOT EDIT)
- `services/api-backend/` — Express 5 ESM, `PORT || 8080`; tests live at repo-root `test/api-backend/`, not in-service
- `services/streaming-proxy/` — Express 5 ESM, `PORT || 3001` (`proxy-server.js`); `dev` is `node --inspect`, not nodemon
- `services/tailscale-relay/` — Express 4 ESM, `PORT || 3002`; has only `start`/`dev` scripts (no lint/test)
- `backend/auth/` — Express 5 **CommonJS** (`"type": "commonjs"`), `PORT || 3000`, entry `handlers.js`; no `dev` script; Jest 29
- `services/sdk/` — TypeScript SDK (ESM, Node `>=26.0.0 <28.0.0`), `main: dist/index.js` — run `npm run build` (`tsc`) before use
- `services/openclaw-skills/pistisai/` — avatar personality skill, tests use **Vitest** (`vitest run`), not Jest
- `lib/shared/` — separate package `pistisai_shared` (Dart `>=3.9.0 <4.0.0`, version `1.0.6+33`) needing its own `flutter pub get`
- Discovery defaults: OpenClaw Gateway `localhost:18789`, Hermes `127.0.0.1:8642`, Ollama `localhost:11434`, LM Studio `localhost:1234`

## Setup & verify (exact commands, from repo root)

```bash
flutter pub get
cd lib/shared && flutter pub get && cd ../..   # shared package deps are separate
npm install                                     # root Node tooling (backend only, NOT the Flutter package)
cd services/api-backend && npm install          # repeat per service you touch
```

CI pins Flutter via exact `environment.flutter` in root `pubspec.yaml` (currently `3.47.7`, stable; workflows use `flutter-version-file: pubspec.yaml`) and Node `26` (`.nvmrc` — **single source of truth** for Node); service engines are Node `>=26.0.0 <28.0.0` (`services/api-backend`, `services/streaming-proxy`, and `services/sdk`). Android builds use AGP `8.11.1`, Gradle `8.14.3`, Kotlin `2.4.0` (Flutter `3.47.7` floor; Gradle 9 / AGP 9 blocked until `tesseract_ocr` drops `jcenter()`). Integration test rig (shared `docker-compose.test.yml` hub): `bash scripts/run_integration_test_rig.sh` (prefers **emulator**, not USB); local PC: `bash scripts/run_pc_integration_test_rig.sh` (`docs/development/testing/PHYSICAL_INTEGRATION_TEST_RIG.md`). USB phone smoke: `scripts/test-android-phone.sh`. CI: `integration-test-rig.yml`; optional self-hosted `integration-test-rig-physical.yml` (label `integration-rig`).

```bash
# Flutter — CI scopes analysis to lib/ only; gate suite is the script, not bare flutter test
flutter analyze lib/
bash scripts/ci/flutter_security_basic_tests.sh   # CI gate: smoke/config/models/utils/helpers + selected services/widgets/integration
flutter build web --release --no-web-resources-cdn  # --no-web-resources-cdn matches CI
dart run build_runner build --delete-conflicting-outputs  # after Drift schema/query changes only

# Backend — root npm test is api-backend security suite only, not a full suite
npm test                  # == cd services/api-backend && npm run test:ci:security
npm run lint              # loops api-backend + streaming-proxy + sdk (tailscale-relay/auth excluded)
npm run format            # loops same 3 services + prettier --write 'test/**/*.js'
npm run test:full          # full root Jest run (cross-env NODE_ENV=test); most tunnel/properties/integration tests are ignore-listed, see jest.config.js

# Per-service (cd into dir first)
# api-backend:     npm run dev | npm run test:unit (../../test/api-backend/, --detectOpenHandles) | npm run test:auth (single file) | npm run lint | npm run db:validate | npm run db:stats | npm run db:test
# streaming-proxy: npm run dev (node --inspect) | npm run health | npm test (uses root jest) | npm run build (tsc) | npm run lint
# sdk:             npm run build (tsc) | npm test (jest ^29) | npm run lint
# openclaw skill:  npm run build (tsc) | npm test (vitest run)
```

## Versioning

Version is tracked in two files that must stay in sync:
- `assets/version.json` — `version` (semver) + `build_number` (integer)
- `pubspec.yaml` — `version: X.Y.Z+<build_number>`

The `build_number` in `assets/version.json` should match the `+<build_number>` suffix in `pubspec.yaml`. When releasing, update both files together. Do not hand-increment `build_number` locally to "stay ahead" — only edit both files when you intend a specific release version.

## Conventions

- Dart: `snake_case.dart`, `PascalCase` classes, single quotes; `implicit-casts:false`, `implicit-dynamic:false` enforced via `analysis_options.yaml`
- JS/TS: `kebab-case` files, `PascalCase` classes; `backend/auth/` is CommonJS, everything else under `services/` is ESM — do not mix `require`/`import` styles across that boundary
- Commits: conventional `feat:`/`fix:`/`docs:`/`chore:`/`test:`/`refactor:` with agent prefix `ai(<agent>): <subject>`; internal agents push to `main`, external contributors use fork → PR (`CONTRIBUTING.md`)
- Platform splits via conditional imports (`dart.library.io` / `dart.library.html`); never import `dart:io` directly in shared code
- Register services via `setupCoreServices()` / `setupAuthenticatedServices()` in `lib/di/locator.dart`; consume via `serviceLocator.get<T>()` — don't instantiate registered services directly
- Desktop auto-bootstraps authenticated services (30s timeout); web requires explicit auth/session bootstrap first
- GitHub issues (`github.com/pistisAI/pistisai-app/issues`, launch tracker #39) are the work-tracking source of truth — check before substantive work

## MCP (OpenCode)

Servers in `opencode.json` (committed; secrets stay in env): `sentry` (needs `opencode mcp auth sentry`), `context7` (package docs), `playwright` (Flutter web E2E), `postgres` (needs `DATABASE_URL` from `.env`). GitHub goes via `gh` CLI (authed, `repo` scope) — no GitHub MCP needed.
Restart OpenCode after editing `opencode.json` so it refetches server tools.

## Pitfalls

- `npm run db:migrate` does NOT exist in api-backend; use `db:validate`, `db:stats`, `db:test`
- Auth backend: no `npm run dev` — run `node handlers.js`
- Tailscale relay is Express 4; api-backend, streaming-proxy, auth are Express 5 — check middleware API against the right major
- Jest `testPathIgnorePatterns` intentionally skips tunnel-*, `*-properties`, `*-integration`, `test/archive/`, and live-Auth0 tests; check `jest.config.js` before assuming a test runs or "passes" by being skipped
- api-backend Jest needs `node --experimental-vm-modules ... --forceExit`; sdk uses plain `jest`
- Don't edit `lib/**/*.g.dart` / `lib/**/*.freezed.dart` — regenerate via build_runner
- Preserve branding exactly: `Pistisai`, `OpenClaw`, `Zoidbot`
