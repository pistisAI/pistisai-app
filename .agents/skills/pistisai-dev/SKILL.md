---
name: pistisai-dev
description: Technical skill guide for developer workflow, toolchains, testing, database generation, and coding rules in the Pistisai Flutter/Node.js project.
---

# Pistisai Project Development Skill

This skill contains the comprehensive developer guidelines, commands, architectural constraints, and toolchains for working with the **Pistisai** codebase (Flutter desktop/web frontend + Node.js backend services).

---

## 1. Repository Layout & Architecture Reference

### Structure Overview

- [lib/](file:///data/dev/projects/pistisai-app/lib/) — Flutter desktop & web application
  - [lib/main.dart](file:///data/dev/projects/pistisai-app/lib/main.dart) — Main entry point
  - [lib/di/locator.dart](file:///data/dev/projects/pistisai-app/lib/di/locator.dart) — Dependency injection registry
  - [lib/database/](file:///data/dev/projects/pistisai-app/lib/database/) — Drift local SQLite database
  - [lib/services/](file:///data/dev/projects/pistisai-app/lib/services/) — Core logic services
  - [lib/screens/](file:///data/dev/projects/pistisai-app/lib/screens/) — UI screens
- [services/](file:///data/dev/projects/pistisai-app/services/) — Node.js backend services
  - [services/api-backend/](file:///data/dev/projects/pistisai-app/services/api-backend/) — Express 5 REST API (Node `>=22 <25`)
  - [services/streaming-proxy/](file:///data/dev/projects/pistisai-app/services/streaming-proxy/) — Streaming proxy (Node `>=22 <25`)
  - [services/tailscale-relay/](file:///data/dev/projects/pistisai-app/services/tailscale-relay/) — Tailscale relay (Express 4)
  - [services/sdk/](file:///data/dev/projects/pistisai-app/services/sdk/) — TypeScript SDK (Node `>=18`)
- [backend/auth/](file:///data/dev/projects/pistisai-app/backend/auth/) — Express 5 Auth0 JWT validation backend (CommonJS, Node `>=22 <25`)

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
- **Linter checks**: `flutter analyze`
- **Run frontend tests**: `flutter test`
- **Run specific test file**: `flutter test test/services/some_test.dart`
- **Code formatting**: `flutter format .`
- **Run local desktop (Linux)**: `flutter run -d linux`
- **Run local web app**: `flutter run -d chrome`
- **Build desktop release package**: `flutter build linux --release`
- **Build web release package**: `flutter build web --release`

### 3.2 Node.js Backend Operations
All backend service directories are ESM (except `backend/auth/` which is CommonJS).

#### API Backend (`services/api-backend/`)
- **Install packages**: `npm install`
- **Start dev server**: `npm run dev`
- **Run unit & integration tests**:
  - Root runner (API tests are at repository root):
    ```bash
    npm test ../../test/api-backend/security/authentication-authorization.test.js
    ```
  - Unit tests: `npm run test:unit`
  - Integration tests: `npm run test:integration`
  - Complete security/auth tests: `npm run test:security` / `npm run test:auth`
- **Database migrations**: `npm run db:migrate`

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
