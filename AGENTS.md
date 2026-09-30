# Pistisai — Agent Guide

Flutter desktop/web app + Node.js backend services: a local-first companion layer for agent runtimes (Hermes, OpenClaw, compatible gateways). Ollama/LM Studio are support model providers for app-owned features only — not primary runtimes unless wrapped by an agent runtime.

## Repo layout

- `pubspec.yaml` — Flutter app (package `pistisai`, version `1.1.26+25`, Dart `>=3.5.0 <4.0.0`)
- `lib/shared/pubspec.yaml` — shared Flutter package (`pistisai_shared`, Dart `>=3.9.0 <4.0.0`)
- `lib/di/locator.dart` — two-phase DI: `setupCoreServices()` → `setupAuthenticatedServices()`
- `lib/database/drift_local_brain.dart` — Drift/SQLite local brain (generated `.g.dart`, DO NOT EDIT)
- `lib/services/router_server.dart` — embedded OpenAI-compatible router (port 1337)
- `package.json` — root Node tooling (ESM), backend only, NOT the Flutter package
- `services/api-backend/` — Express 5 (ESM, Node `>=22 <27`, port 8080)
- `services/streaming-proxy/` — Express 5 (ESM, Node `>=22 <27`, port 3001)
- `services/sdk/` — TypeScript SDK (ESM, Node `>=18`)
- `services/tailscale-relay/` — Express 4 (ESM, port 3002; uses Express 4, not 5)
- `backend/auth/` — Express 5 (CommonJS, port 3000; no `dev` script, `test` is a placeholder)
- `services/openclaw-skills/pistisai/` — avatar personality skill (ESM, TypeScript, Vitest)
- `test/api-backend/` — backend tests at root, NOT in `services/api-backend/test/`

## Setup & build

```bash
cd /d/dev/projects/pistisai-app
flutter pub get                    # Flutter app
cd lib/shared && flutter pub get   # shared package
cd ../..
npm install                        # root Node tooling
cd services/api-backend && npm install   # API backend
```

CI uses Flutter 3.44.6 (stable) and Node 26.

```bash
# Flutter (from repo root)
flutter analyze lib/
flutter test test/smoke/
bash scripts/ci/flutter_security_basic_tests.sh   # CI gate subset
flutter build linux --release
flutter build web --release
dart run build_runner build --delete-conflicting-outputs   # after Drift schema/query changes

# Backend (from repo root)
npm run lint              # lints api-backend + streaming-proxy + sdk
npm run format            # formats selected services + root test/
npm test                  # runs api-backend test:ci:security

# Per-service (cd into dir first)
# api-backend:      npm run dev && npm run test:ci:security && npm run test:unit && npm run lint
# streaming-proxy:  npm run dev && npm run health && npm test && npm run build && npm run lint
# sdk:              npm run build && npm test && npm run lint
# openclaw skills:  npm run build && npm test
```

## Version bumping

Every push to `main` with code changes must bump version in both `assets/version.json` and `pubspec.yaml`:

```bash
CURRENT=$(jq -r '.version' assets/version.json)   # e.g. 1.1.26
NEW_VERSION="1.1.27"   # new patch/minor/major
BUILD_NUM=$(jq -r '.build_number' assets/version.json)
jq ".version = \"$NEW_VERSION\" | .build_number = \"$((BUILD_NUM + 1))\"" assets/version.json > v.tmp && mv v.tmp assets/version.json
sed -i "s/^version: .*/version: $NEW_VERSION+$(jq -r '.build_number' assets/version.json)/" pubspec.yaml
```

`auto-version-bump.yml` auto-bumps patch on push to main if `version.json` wasn't changed. Commit `[major]` or `[minor]` to control bump level.

## Conventions

- Dart: `snake_case.dart` files, `PascalCase` classes, single quotes, `implicit-casts:false`, `implicit-dynamic:false`
- JS/TS: `kebab-case`, `PascalCase` classes; `backend/auth/` is CommonJS, everything else under `services/` is ESM
- Commits: `ai(<agent>): <subject>` — e.g. `ai(Zoidbot): fix window spam`. Push directly to `main` unless a branch is explicitly requested.
- Platform splits via conditional imports (`dart.library.io` / `dart.library.html` / `dart.library.js_interop`); never import `dart:io` directly in shared code
- Use `serviceLocator.get<T>()` / `di.serviceLocator<T>()` — don't instantiate registered services directly
- Agent runtime discovery: Hermes, OpenClaw Gateway `localhost:18789`, custom gateways
- Local model discovery (memory/embeddings only): LM Studio `localhost:1234`, Ollama `localhost:11434`

## Pitfalls

- Don't edit generated `lib/**/*.g.dart` or `lib/**/*.freezed.dart` — regenerate via build_runner
- `npm run db:migrate` does NOT exist in api-backend; use `db:validate`, `db:stats`, `db:test`
- Auth backend: no `npm run dev` — run `node handlers.js`; `npm test` is a placeholder (exits with error)
- Tailscale relay uses Express 4; api-backend, streaming-proxy, and auth use Express 5
- Root `npm test` runs only api-backend security tests — not a full suite
- Jest's `testPathIgnorePatterns` intentionally skips many live-infrastructure tests; check `jest.config.js` before assuming a test runs
- Drift schema or query changes require `dart run build_runner build --delete-conflicting-outputs`
- Web requires explicit auth/session bootstrap before authenticated services are available
- Version bump must update BOTH `assets/version.json` AND `pubspec.yaml`
- GitHub issues at `https://github.com/pistisAI/pistisai-app/issues` are the source of truth — check before starting substantive work
