import '../connection_manager_service.dart';
import 'hermes_runtime_client.dart';

/// Whether the app has a runtime selected and whether it answered.
enum RuntimeLinkState {
  /// No agent runtime is selected in settings.
  unconfigured,

  /// The runtime answered the latest health check.
  connected,

  /// A runtime is selected but did not answer the latest health check.
  disconnected,
}

/// What the app actually knows about the active agent runtime.
///
/// Built only from [ConnectionManagerService] state, so screens show the
/// runtime the app talks to (the saved Hermes URL) instead of placeholder
/// values (#857).
class RuntimeStatusSnapshot {
  const RuntimeStatusSnapshot({
    required this.state,
    this.runtimeName,
    this.endpoint,
    this.port,
    this.apiKeySet = false,
    this.modelCount = 0,
    this.lastError,
  });

  factory RuntimeStatusSnapshot.fromConnectionManager(
    ConnectionManagerService service,
  ) {
    final client = service.activeRuntimeClient;
    if (service.currentBackend == null || client == null) {
      return const RuntimeStatusSnapshot(state: RuntimeLinkState.unconfigured);
    }

    final identity = client.identity;
    final endpoint = identity.baseUrl.trim().isEmpty ? null : identity.baseUrl;
    final uri = endpoint == null ? null : Uri.tryParse(endpoint);
    final port = uri != null && uri.host.isNotEmpty ? uri.port : null;
    final apiKey = client is HermesRuntimeClient ? client.apiKey : null;
    final error = service.lastError;

    return RuntimeStatusSnapshot(
      state: service.isConnected
          ? RuntimeLinkState.connected
          : RuntimeLinkState.disconnected,
      runtimeName: identity.name,
      endpoint: endpoint,
      port: port,
      apiKeySet: apiKey != null && apiKey.isNotEmpty,
      modelCount: service.availableModels.length,
      lastError: service.isConnected || error == null || error.isEmpty
          ? null
          : error,
    );
  }

  final RuntimeLinkState state;

  /// Display name the runtime client reports, e.g. "Hermes Agent".
  final String? runtimeName;

  /// Base URL the app sends requests to.
  final String? endpoint;

  /// Port parsed from [endpoint].
  final int? port;

  /// Whether an API key is configured for the runtime. The key itself is
  /// never exposed.
  final bool apiKeySet;

  /// Number of models the runtime reported on its last successful check.
  final int modelCount;

  /// Error from the latest failed check, if any.
  final String? lastError;
}
