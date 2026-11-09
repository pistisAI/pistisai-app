---
name: iacle-dev
description: Technical skill guide for developer workflow, toolchains, testing, database generation, and coding rules in the IAClé Flutter/Node.js project.
---

# IAClé Project Development Skill

This skill contains the comprehensive developer guidelines, commands, architectural constraints, and toolchains for working with the **IAClé** codebase (Flutter desktop/web frontend + Node.js backend services).

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
  - [services/api-backend/](../../../services/api-backend/) — Express 5 REST API (Node `>=22 <27`)
  - [services/streaming-proxy/](../../../services/streaming-proxy/) — Streaming proxy (Node `>=22 <27`)
  - [services/tailscale-relay/](../../../services/tailscale-relay/) — Tailscale relay (Express 4)
  - [services/sdk/](../../../services/sdk/) — TypeScript SDK (Node `>=18`)
- [backend/auth/](../../../backend/auth/) — Express 5 Auth0 JWT validation backend (CommonJS, Node `>=22 <27`)

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

- **Get dependencies**: `flutter pub get`
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
- **Run unit tests**:
  - Root runner (API tests are at repository root):
    ```bash
    npm test ../../test/api-backend/security/authentication-authorization.test.js
    ```
  - Unit tests: `npm run test:unit`
  - Complete security/auth tests: `npm run test:security` / `npm run test:auth`
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

- **Push directly to `main`** by default. Do not use PRs or branches unless:
  1. Specifically requested by the user.
  2. Working on highly experimental/breaking features.
- **Commit Formatting**: Prefix commits with the agent name in this format:
  ```text
  ai(Antigravity): <description of changes>
  ```
- **Tests verification**: Ensure `flutter analyze` and root `npm test` pass before pushing.
