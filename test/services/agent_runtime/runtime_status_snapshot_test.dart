import 'package:flutter_test/flutter_test.dart';
import 'package:pistisai/services/agent_runtime/agent_runtime_client.dart';
import 'package:pistisai/services/agent_runtime/hermes_runtime_client.dart';
import 'package:pistisai/services/agent_runtime/runtime_status_snapshot.dart';
import 'package:pistisai/services/connection_manager_service.dart';
import 'package:pistisai/services/hermes/hermes_streaming_service.dart';

class _FakeConnectionManager extends ConnectionManagerService {
  _FakeConnectionManager({
    this.backend,
    this.client,
    this.connected = false,
    this.models = const <String>[],
    this.error,
  }) : super(hermesStreamingService: HermesStreamingService());

  final BackendType? backend;
  final AgentRuntimeClient? client;
  final bool connected;
  final List<String> models;
  final String? error;

  @override
  BackendType? get currentBackend => backend;

  @override
  AgentRuntimeClient? get activeRuntimeClient => client;

  @override
  bool get isConnected => connected;

  @override
  List<String> get availableModels => models;

  @override
  String? get lastError => error;
}

void main() {
  group('RuntimeStatusSnapshot (#857)', () {
    test('is unconfigured when no runtime is selected', () {
      final snapshot = RuntimeStatusSnapshot.fromConnectionManager(
        _FakeConnectionManager(),
      );
      expect(snapshot.state, RuntimeLinkState.unconfigured);
      expect(snapshot.endpoint, isNull);
      expect(snapshot.port, isNull);
    });

    test('reports the saved Hermes URL, port, key presence and models', () {
      final snapshot = RuntimeStatusSnapshot.fromConnectionManager(
        _FakeConnectionManager(
          backend: BackendType.hermes,
          client: HermesRuntimeClient(
            baseUrl: 'http://runtime.example.com:9000',
            apiKey: 'test-key',
          ),
          connected: true,
          models: const <String>['model-a', 'model-b'],
        ),
      );
      expect(snapshot.state, RuntimeLinkState.connected);
      expect(snapshot.endpoint, 'http://runtime.example.com:9000');
      expect(snapshot.port, 9000);
      expect(snapshot.apiKeySet, isTrue);
      expect(snapshot.modelCount, 2);
      expect(snapshot.lastError, isNull);
    });

    test('carries the last error when the runtime is not reachable', () {
      final snapshot = RuntimeStatusSnapshot.fromConnectionManager(
        _FakeConnectionManager(
          backend: BackendType.hermes,
          client: HermesRuntimeClient(baseUrl: 'http://127.0.0.1:8642'),
          error: 'Connection refused',
        ),
      );
      expect(snapshot.state, RuntimeLinkState.disconnected);
      expect(snapshot.apiKeySet, isFalse);
      expect(snapshot.lastError, 'Connection refused');
    });
  });
}
