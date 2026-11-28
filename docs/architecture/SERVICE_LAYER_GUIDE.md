# Service layer and DI guide

How Flutter services are registered and consumed. Source of truth:
`lib/di/locator.dart`.

## Two-phase bootstrap

| Phase | Function | When |
|-------|----------|------|
| Core | `setupCoreServices()` | App start (all platforms) |
| Authenticated | `setupAuthenticatedServices()` | After session/auth is ready |

- **Desktop:** core registration auto-bootstraps authenticated services (30s
  timeout) so local hub features work without a cloud sign-in.
- **Web:** authenticated services wait for explicit auth/session bootstrap.

Both phases are idempotent via guards (`_coreServicesRegistered`,
`_authenticatedServicesRegistered`).

## How to obtain a service

```dart
import 'package:pistisai/di/locator.dart';

final discovery = serviceLocator.get<ProviderDiscoveryService>();
```

Do **not** construct registered services with `FooService()` in feature code.
Direct construction is reserved for:

- the locator registration site itself
- tests that register fakes into `serviceLocator`
- short-lived value objects / pure helpers that are not DI services

## Core vs authenticated

### Core (examples)

Local-first and bootstrap dependencies, including when unauthenticated:

- `SettingsPreferenceService`, `SessionStorageService`, `TokenStorageService`
- `LocalBrain` (Drift/SQLite or web WASM)
- Desktop avatar graph: `PersonalityEngine`, `EvolutionTracker`, `MemoryService`,
  `AvatarStateService`, `MarkdownSyncService`
- Embedded `RouterServer` (loopback by default; remote only with explicit flag)
- `HermesStreamingService`, voice services
- `ProviderDiscoveryService`, `AuthProvider` / `AuthService`, theme/settings,
  onboarding (`SetupWizardService`), gateway control

Cloud model adapters (`ZhipuAdapter`, `GoogleAdapter`, `MoonshotAdapter`) are
registered on the router **only** when the corresponding build-time API key
(`GLM_API_KEY`, `GEMINI_API_KEY`, `KIMI_API_KEY`) is non-empty.

### Authenticated (examples)

Tunnel/sync and cloud-adjacent surfaces that assume a session:

- `TunnelConfigManager`, `TunnelService`, `StreamingProxyService`
- `CloudConnectorService`, `ConnectionManagerService`
- Related metrics / bridge helpers mounted after auth

## Boundary rules

1. **UI → services via locator.** Screens and widgets call
   `serviceLocator.get<T>()` (or receive the service from a parent that did).
2. **Services may depend on other services** registered in an earlier or the
   same phase; prefer constructor injection at registration time over late
   `get` inside hot paths when the dependency is required.
3. **Local services stay local.** The embedded router binds loopback unless
   remote hub access is explicitly enabled in Settings → Connections (or a
   custom build sets `ROUTER_ALLOW_REMOTE_ACCESS`). Either way every private
   endpoint requires an `authSecret` before other devices may use it.
4. **Nothing leaves the device without consent.** New outbound hosts, SDKs, or
   telemetry must be opt-in and listed in privacy docs in the same change.
5. **Platform splits** use conditional imports (`dart.library.io` /
   `dart.library.html`). Shared libraries must not import `dart:io` directly.

## Audit notes (spot check)

Random call sites should use the locator for registered types. Acceptable
exceptions: `SettingsPreferenceService()` inside discovery when resolving
Hermes URL before a test double is injected; ephemeral HTTP/process helpers.

When adding a service:

1. Register it in the correct phase in `locator.dart`.
2. Document any new outbound network dependency in privacy docs.
3. Consume it with `serviceLocator.get<T>()`.
4. Prefer a fake registered in tests over mocking constructors.
