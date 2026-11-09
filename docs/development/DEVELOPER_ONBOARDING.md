# Developer Onboarding

This guide is the entry point for working on the Pistisai stack. Product description: [README](../../README.md).

## Repository Shape

| Path | Purpose |
| --- | --- |
| `lib/` | Flutter desktop/web app |
| `lib/di/locator.dart` | GetIt service registration and two-phase DI |
| `lib/database/` | Drift/SQLite local brain |
| `lib/services/` | Flutter service layer |
| `services/api-backend/` | Express 5 API backend |
| `services/streaming-proxy/` | Streaming proxy service |
| `services/sdk/` | TypeScript SDK |
| `services/tailscale-relay/` | Tailscale relay |
| `backend/auth/` | Lightweight CommonJS Auth0 backend |
| `test/` | Flutter tests and root API backend Jest tests |
| `docs/` | Documentation |
| `scripts/` | Build, deployment, maintenance, and release helpers |

## Required Tools

- Flutter matching `environment.flutter` in `pubspec.yaml` (currently `3.47.7`) with Dart `>=3.5.0 <4.0.0`.
- Node.js `>=22 <27` for `services/api-backend/` and `services/streaming-proxy/` (CI pins Node `26` via `.nvmrc`).
- Node.js `>=18` is sufficient for `services/sdk/`.
- Docker or a compatible container runtime for backend/deployment work.
- PostgreSQL for backend database work.

## Initial Setup

```bash
flutter pub get
cd lib/shared && flutter pub get && cd ../..
flutter analyze lib/
bash scripts/ci/flutter_security_basic_tests.sh
```

For API backend work:

```bash
cd services/api-backend
npm install
npm test
```

For streaming proxy work:

```bash
cd services/streaming-proxy
npm install
npm test
```

Dev servers:

```bash
cd services/api-backend && npm install && npm run dev
cd services/streaming-proxy && npm install && npm run dev
```

For SDK work:

```bash
cd services/sdk
npm install
npm run build
npm test
```

## Core Development Rules

- Use `di.serviceLocator<T>()` or `serviceLocator.get<T>()` for registered Flutter services.
- Do not instantiate long-lived services directly unless the file already uses a local helper pattern.
- Do not import `dart:io` in shared Flutter code; use conditional imports or platform helpers.
- If you change Drift table definitions or queries, run:

```bash
dart run build_runner build --delete-conflicting-outputs
```

- Do not edit generated `*.g.dart` or `*.freezed.dart` files.
- Backend services under `services/` are ESM unless their package says otherwise.
- `backend/auth/` is CommonJS and has no `npm run dev`; run it with `node handlers.js`.

## Common Commands

```bash
bash tool/brand.sh pistisai
flutter analyze lib/
bash scripts/ci/flutter_security_basic_tests.sh
flutter test --dart-define=BRAND=pistisai test/services/some_test.dart
dart format .
flutter run -d linux --dart-define=BRAND=pistisai
flutter run -d windows --dart-define=BRAND=pistisai
flutter run -d chrome --dart-define=BRAND=pistisai
flutter build linux --release --dart-define=BRAND=pistisai
flutter build web --release --no-web-resources-cdn --dart-define=BRAND=pistisai
flutter build apk --release --split-per-abi --dart-define=BRAND=pistisai
flutter build windows --release --dart-define=BRAND=pistisai
flutter build macos --release --dart-define=BRAND=pistisai
```

```bash
npm test                  # api-backend security CI suite only
# npm run test:full       # broader Jest run; see jest.config.js ignore-list
npm run docs:links

# Service dev servers
cd services/api-backend && npm install && npm run dev
cd services/streaming-proxy && npm install && npm run dev
```

`npm run docs:links` validates the canonical documentation set. `npm run docs:links:all` scans the full markdown tree.

## Where To Read Next

- [Documentation Hub](../README.md)
- [System Architecture](../architecture/SYSTEM_ARCHITECTURE.md)
- [Development Workflow](DEVELOPMENT_WORKFLOW.md)
- [Building Guide](BUILDING_GUIDE.md)
- [Comprehensive Testing Guide](testing/COMPREHENSIVE_TESTING_GUIDE.md)
- [Deployment Index](../deployment/README.md)
