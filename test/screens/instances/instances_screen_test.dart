import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pistisai/di/locator.dart' as di;
import 'package:pistisai/l10n/app_localizations.dart';
import 'package:pistisai/models/provider_configuration.dart';
import 'package:pistisai/screens/instances/instances_screen.dart';
import 'package:pistisai/services/agent_runtime/agent_runtime_client.dart';
import 'package:pistisai/services/agent_runtime/hermes_runtime_client.dart';
import 'package:pistisai/services/connection_manager_service.dart';
import 'package:pistisai/services/hermes/hermes_streaming_service.dart';
import 'package:pistisai/services/provider_discovery_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeConnectionManager extends ConnectionManagerService {
  _FakeConnectionManager({
    required this.backend,
    this.client,
    this.healthy = false,
    this.error,
  }) : super(hermesStreamingService: HermesStreamingService());

  final BackendType? backend;
  final AgentRuntimeClient? client;
  final bool healthy;
  final String? error;
  int healthChecks = 0;

  @override
  Future<bool> testConnection() async {
    healthChecks++;
    return healthy;
  }

  @override
  BackendType? get currentBackend => backend;

  @override
  AgentRuntimeClient? get activeRuntimeClient => client;

  @override
  bool get isConnected => healthy;

  @override
  String? get lastError => error;
}

class _FakeProviderDiscoveryService implements ProviderDiscoveryService {
  _FakeProviderDiscoveryService({this.providers = const [], this.fail = false});

  final List<ProviderInfo> providers;
  final bool fail;

  @override
  Future<List<ProviderInfo>> scanForProviders() async {
    if (fail) throw StateError('scan failed');
    return providers;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  void register<T extends Object>(T instance) {
    if (di.serviceLocator.isRegistered<T>()) {
      di.serviceLocator.unregister<T>();
    }
    di.serviceLocator.registerSingleton<T>(instance);
  }

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  tearDown(() {
    for (final unregister in [
      () => di.serviceLocator.unregister<ConnectionManagerService>(),
      () => di.serviceLocator.unregister<ProviderDiscoveryService>(),
    ]) {
      try {
        unregister();
      } catch (_) {}
    }
  });

  Future<void> pumpScreen(WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: InstancesScreen(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump();
  }

  group('InstancesScreen (#857)', () {
    testWidgets('shows the Hermes runtime the app uses, without fake controls',
        (tester) async {
      final connection = _FakeConnectionManager(
        backend: BackendType.hermes,
        client: HermesRuntimeClient(baseUrl: 'http://runtime.example.com:9000'),
        healthy: true,
      );
      register<ConnectionManagerService>(connection);
      register<ProviderDiscoveryService>(_FakeProviderDiscoveryService(
        providers: const [
          ProviderInfo(
            id: 'ollama',
            name: 'Ollama',
            type: ProviderType.ollama,
            url: 'http://localhost:11434',
            isAvailable: true,
            availableModels: ['model-a'],
          ),
        ],
      ));

      await pumpScreen(tester);

      // A real health check ran against the configured runtime.
      expect(connection.healthChecks, 1);
      expect(find.text('CONNECTED'), findsOneWidget);
      expect(
        find.text('Endpoint: http://runtime.example.com:9000'),
        findsOneWidget,
      );
      expect(find.text('Port 9000'), findsOneWidget);

      // No Start/Stop/Restart that would drive a different runtime.
      expect(find.text('Start'), findsNothing);
      expect(find.text('Stop'), findsNothing);
      expect(find.text('Restart'), findsNothing);
      expect(
        find.textContaining('not available yet'),
        findsOneWidget,
      );

      // Model cards show the model, not invented load or tier figures.
      expect(find.text('model-a'), findsOneWidget);
      expect(find.text('0/10'), findsNothing);
      expect(find.text('CRITICAL'), findsNothing);
      expect(find.text('MEDIUM'), findsNothing);
      expect(find.textContaining('% utilized'), findsNothing);
    });

    testWidgets('says so when no runtime is selected', (tester) async {
      final connection = _FakeConnectionManager(backend: null);
      register<ConnectionManagerService>(connection);
      register<ProviderDiscoveryService>(_FakeProviderDiscoveryService());

      await pumpScreen(tester);

      expect(connection.healthChecks, 0);
      expect(find.text('NOT CONFIGURED'), findsOneWidget);
      expect(find.textContaining('No agent runtime is selected'),
          findsOneWidget);
      expect(find.text('No model providers found on this device.'),
          findsOneWidget);
    });

    testWidgets('surfaces a provider scan failure', (tester) async {
      register<ConnectionManagerService>(
        _FakeConnectionManager(
          backend: BackendType.hermes,
          client: HermesRuntimeClient(baseUrl: 'http://127.0.0.1:8642'),
          error: 'Connection refused',
        ),
      );
      register<ProviderDiscoveryService>(
        _FakeProviderDiscoveryService(fail: true),
      );

      await pumpScreen(tester);

      expect(find.text('NOT REACHABLE'), findsOneWidget);
      expect(find.text('Connection refused'), findsOneWidget);
      expect(find.textContaining('Could not scan model providers'),
          findsOneWidget);
    });
  });
}
