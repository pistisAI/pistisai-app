---
name: pistisai-dev
description: Technical skill guide for developer workflow, toolchains, testing, database generation, and coding rules in the Pistisai Flutter/Node.js project.
---

# Pistisai Project Development Skill

This skill contains the comprehensive developer guidelines, commands, architectural constraints, and toolchains for working with the **Pistisai** codebase (Flutter desktop/web frontend + Node.js backend services).

---

## 1. Repository Layout & Architecture Reference

### Structure Overview

- [lib/](../../../lib/) — Flutter desktop & web application
  - [lib/main.dart](../../../lib/main.dart) — Main entry point
  - [lib/di/locator.dart](../../../lib/di/locator.dart) — Dependency injection registry
  - [lib/database/](../../../lib/database/) — Drift local SQLite database
  - [lib/services/](../../../lib/services/) — Core logic services
  - [lib/screens/](../../../lib/screens/) — UI screens
- [services/](../../../services/) — Node.js backend services
  - [services/api-backend/](../../../services/api-backend/) — Express 5 REST API (Node `>=26.0.0 <28.0.0`)
  - [services/streaming-proxy/](../../../services/streaming-proxy/) — Streaming proxy (Node `>=26.0.0 <28.0.0`)
  - [services/tailscale-relay/](../../../services/tailscale-relay/) — Tailscale relay (Express 4; no `engines` field; use Node 26 from `.nvmrc`)
  - [services/sdk/](../../../services/sdk/) — TypeScript SDK (Node `>=26.0.0 <28.0.0`)
- [backend/auth/](../../../backend/auth/) — Express 5 Auth0 JWT validation backend (CommonJS; no `engines` field; use Node 26 from `.nvmrc`)

---

## 2. Core Architectural & Coding Constraints

### 2.1 Web vs Native Splits (Platform Boundaries)
Do **not** import `dart:io` in shared Flutter code. Use conditional imports or existing platform adapters (`lib/services/platform_adapter.dart`).
Conditional imports should use the standard Dart pattern:
```dart
import 'thing.dart'
    if (dart.library.io) 'thing_io.dart'
    if (dart.library.html) 'thing_web.dart';
```

### 2.2 Two-Phase Dependency Injection
All services are registered inside `lib/di/locator.dart` via `GetIt`:
1. **Core Services** (`setupCoreServices()`): Registers pre-authentication services (preferences, LocalBrain, platform detection, setup wizard, etc.).
2. **Authenticated Services** (`setupAuthenticatedServices()`): Registers auth-dependent services (desktop control, tunnel, LLM providers, vision, gateway control, etc.).

**Rule:** Always retrieve services using `serviceLocator<T>()` or `serviceLocator.get<T>()`. Never instantiate registered singleton services manually.

### 2.3 Drift SQLite Local Brain Schema Changes
When you modify Drift table definitions or queries in `lib/database/`, you must rebuild the generated part files (`*.g.dart` or `*.freezed.dart`).
- Do **not** edit generated files manually.
- Run the code generator:
  ```bash
  dart run build_runner build --delete-conflicting-outputs
  ```

---

## 3. Toolchain & Command Runbook

### 3.1 Flutter Frontend Operations
Run these commands from the root directory of the repository:

- **Get dependencies**: `flutter pub get` then `cd lib/shared && flutter pub get && cd ../..`
- **Linter checks**: `flutter analyze lib/`
- **CI Flutter gate**: `bash scripts/ci/flutter_security_basic_tests.sh`
- **Run specific test file**: `flutter test test/services/some_test.dart`
- **Code formatting**: `dart format .`
- **Run local desktop (Linux)**: `flutter run -d linux`
- **Run local web app**: `flutter run -d chrome`
- **Build desktop release package**: `flutter build linux --release`
- **Build web release package**: `flutter build web --release --no-web-resources-cdn`

### 3.2 Node.js Backend Operations
All backend service directories are ESM (except `backend/auth/` which is CommonJS).

#### API Backend (`services/api-backend/`)
- **Install packages**: `npm install`
- **Start dev server**: `npm run dev`
- **Run unit & integration tests** (from `services/api-backend/`; Jest files live at repo-root `test/api-backend/`):
  - Auth tests: `npm run test:auth`
  - Unit tests: `npm run test:unit`
  - Integration tests: `npm run test:integration`
  - Security suite: `npm run test:security`
- **Database helpers**: `npm run db:validate` / `npm run db:stats` / `npm run db:test` (there is no `db:migrate`)

#### Streaming Proxy (`services/streaming-proxy/`)
- **Install & dev**: `npm install && npm run dev`
- **Build TypeScript**: `npm run build`
- **Run tests**: `npm test`

#### Auth Backend (`backend/auth/`)
- **Install packages**: `npm install`
- **Run server**: `node handlers.js` (Note: there is no `npm run dev` script)

---

## 4. Git & Branch Discipline

- **Commits**: conventional `feat:` / `fix:` / `docs:` / `chore:` / `test:` / `refactor:` with agent prefix `ai(<agent>): <subject>`.
- **Internal agents** push to `main`. **External contributors** use fork → PR ([CONTRIBUTING.md](../../../CONTRIBUTING.md)).
- **Tests verification**: Ensure `flutter analyze lib/` and root `npm test` pass before pushing.
