# Service Lifecycle & Dependency Graph

Pistisai uses a centralized service locator (`lib/di/locator.dart`) to ensure that long-lived services are constructed once during bootstrap and disposed in a predictable order.

## Boot Sequence

1. `AppBootstrapper.load()` (see `lib/bootstrap/bootstrapper.dart`)
   - Configures SQLite FFI when running on desktop.
   - Invokes `setupServiceLocator()`, a compatibility wrapper that delegates to `setupCoreServices()` (`lib/di/locator.dart:1260-1261`). Core services register in `setupCoreServices()` (:137) and auth-dependent services register separately in `setupAuthenticatedServices()` (:832). On desktop the authenticated phase is auto-bootstrapped with a 30s timeout (:650); on web it follows an explicit session bootstrap via `_registerWebFallbackCoreServices()` (:704).
   - Returns `AppBootstrapData` so the root widget tree can decide whether to render native shell affordances.
2. `main.dart`
   - Wraps the app with a `FutureProvider<AppBootstrapData?>` and waits for bootstrap to finish.
   - Provides all registered services via `ChangeNotifierProvider.value` so they are not re-created by the widget tree.
3. `HomeScreen`
   - Uses `LayoutBuilder` / `HomeLayout` for responsive UI.
   - Requests services from the provider tree (which ultimately resolves through the service locator).

## Service Dependencies

`lib/di/locator.dart` registers services in **two phases**. The names below are the classes actually registered there (checked against the `registerSingleton<...>` / `registerLazySingleton<...>` calls); older revisions of this graph named helpers that do not exist (`AgentRuntimeDiscovery`, `LocalModelProviderDiscovery`, `ProviderDiscovery`, `LangChainIntegration`, `UserContainerService`, `AgentRuntimeServices`, `UnifiedConnection`).

| Phase | Registration function | Representative registered services |
| --- | --- | --- |
| Core / pre-auth | `setupCoreServices()` (line 137) | `AuthProvider`, `AuthService`, `LocalBrain`, `AgentActionAuditService`, avatar services, `RouterServer`, `HermesStreamingService`, `ProviderDiscoveryService`, `ProviderConfigurationManager`, `PlatformDetectionService`, `PlatformAdapter`, `SetupWizardService`, `EnhancedUserTierService` |
| Authenticated | `setupAuthenticatedServices()` (line 832) | `TunnelService`, `CloudConnectorService`, `ConnectionManagerService`, `StreamingChatService`, `UnifiedConnectionService`, `AgentStatusService`, `AgentLifecycleService`, `AdminCenterService`, `AdminService`, `ClipboardService`, `MainVisionService`, `RegionCaptureService`, `CameraCaptureService`, `OcrEngineService`, `PopOutManager` |

Constructor dependencies visible in the locator include `TunnelService(authService: ...)` (:906), `AdminCenterService(authService: ...)` (:1063) and `PlatformAdapter(platformDetectionService)` (:528). `ProviderDiscoveryService.scanForAgentRuntimes()` only scans Hermes today (`lib/services/provider_discovery_service.dart:44-46`).

Legend:

- **AuthProvider** is the provider-agnostic auth interface; `setupCoreServices()` selects `CloudflareAccessAuthProvider` (`lib/di/locator.dart:392-423`) and passes it to `AuthService` (:435). The earlier "Auth0Service" name was stale.
- **AuthService** publishes authentication state and is the primary trigger for services that depend on user session context.
- **ConnectionManagerService** orchestrates the selected agent runtime path. Hermes is the first test path and the only runtime auto-scanned today (`lib/services/provider_discovery_service.dart:44-46`); OpenClaw and compatible gateways are configured/selected in setup.
- **Local model providers** such as Ollama and LM Studio belong to memory/background feature support, not the main agent channel.
- **Tailscale-first secure mesh** is the preferred multi-device transport. Custom tunnel services are legacy/fallback unless a task explicitly targets them.

## Lifecycle Contract

- Every service that registers with `setupCoreServices()` or `setupAuthenticatedServices()` **must**:
  - Accept dependencies via constructor injection only.
  - Provide an `initialize()` (or equivalent) method that completes before the service is exposed to the widget tree.
  - Remove listeners and close streams inside `dispose()` if they allocate platform resources.

- The service locator is populated in **two phases**, not a single scope: `setupCoreServices()` for pre-auth services and `setupAuthenticatedServices()` for auth-dependent ones (`lib/di/locator.dart:137,832`). Do not resolve an authenticated service during the core phase.

## Logging

All services use `appLogger` (`lib/utils/logger.dart`) instead of `debugPrint` so log output can be redirected or persisted. The logger defaults to a concise, non-colored printer that works well inside GitHub Actions logs.
