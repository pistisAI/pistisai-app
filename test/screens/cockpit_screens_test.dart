import 'package:pistisai/models/channel.dart';
import 'package:pistisai/models/provider_configuration.dart';
import 'package:pistisai/models/session.dart';
import 'package:pistisai/screens/channels/channels_screen.dart';
import 'package:pistisai/screens/instances/instances_screen.dart';
import 'package:pistisai/screens/sessions/sessions_screen.dart';
import 'package:pistisai/services/channel_service.dart';
import 'package:pistisai/services/connection_manager_service.dart';
import 'package:pistisai/services/openclaw_manager/gateway_control_service.dart';
import 'package:pistisai/services/provider_discovery_service.dart';
import 'package:pistisai/services/settings_preference_service.dart';
import 'package:pistisai/services/session_service.dart';
import 'package:pistisai/di/locator.dart' as di;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeChannelService implements ChannelService {
  @override
  Future<List<GatewayChannel>> listChannels() async => [];
}

class _FakeSessionService implements SessionService {
  @override
  Future<List<SessionData>> listSessions({int limit = 50}) async => [];

  @override
  Future<bool> terminate(String id) async => true;
}

class _FakeProviderDiscoveryService implements ProviderDiscoveryService {
  @override
  Future<List<ProviderInfo>> scanForAgentRuntimes() async => [];

  @override
  Future<List<ProviderInfo>> scanForSupportModelProviders() async => [];

  @override
  Future<List<ProviderInfo>> scanForProviders() async => [];

  @override
  Future<ConnectionTestResult> testConnection(String url) async =>
      ConnectionTestResult(isConnected: false, url: url, message: 'Mock');

  @override
  void startPeriodicScanning({Duration interval = const Duration(seconds: 30)}) {}

  @override
  void stopPeriodicScanning() {}

  @override
  Future<bool> isProviderTypeAvailable(ProviderType type) async => false;

  @override
  Future<List<TailscaleDevice>> discoverTailscaleDevices() async => [];
}

class _FakeSettingsPreferenceService extends SettingsPreferenceService {
  @override
  Future<bool> getGatewayAutoRestart() async => true;

  @override
  Future<void> setGatewayAutoRestart(bool enabled) async {}

  @override
  Future<String?> getHermesUrl() async => null;

  @override
  Future<void> setHermesUrl(String? url) async {}

  @override
  Future<String?> getHermesApiKey() async => null;

  @override
  Future<void> setHermesApiKey(String? key) async {}
}

class _FakeGatewayControlService extends ChangeNotifier implements GatewayControlService {
  final GatewayState _state = GatewayState.stopped;
  String? _errorMessage;
  DateTime? _startedAt;
  bool _autoRestartEnabled = true;

  @override
  GatewayState get state => _state;

  @override
  String? get errorMessage => _errorMessage;

  @override
  DateTime? get startedAt => _startedAt;

  @override
  bool get isRunning => _state == GatewayState.running;

  @override
  bool get isStarting => _state == GatewayState.starting;

  @override
  bool get isStopping => _state == GatewayState.stopping;

  @override
  bool get autoRestartEnabled => _autoRestartEnabled;

  @override
  Future<bool> start() async => true;

  @override
  Future<bool> stop() async => true;

  @override
  Future<bool> restart() async => true;

  @override
  Future<Map<String, dynamic>> getStatus() async => {
        'state': _state.name,
        'isRunning': isRunning,
        'startedAt': _startedAt?.toIso8601String(),
        'errorMessage': _errorMessage,
      };

  @override
  Future<void> setAutoRestart(bool enabled) async {
    _autoRestartEnabled = enabled;
  }

  @override
  Future<void> checkStatus() async {}

  @override
  void setConnectionManager(ConnectionManagerService connectionManager) {}
}

void main() {
  late _FakeChannelService channelService;
  late _FakeSessionService sessionService;
  late _FakeProviderDiscoveryService providerDiscovery;
  late _FakeGatewayControlService gatewayService;

  setUp(() {
    channelService = _FakeChannelService();
    sessionService = _FakeSessionService();
    providerDiscovery = _FakeProviderDiscoveryService();
    gatewayService = _FakeGatewayControlService();

    if (di.serviceLocator.isRegistered<ChannelService>()) {
      di.serviceLocator.unregister<ChannelService>();
    }
    di.serviceLocator.registerSingleton<ChannelService>(channelService);

    if (di.serviceLocator.isRegistered<SessionService>()) {
      di.serviceLocator.unregister<SessionService>();
    }
    di.serviceLocator.registerSingleton<SessionService>(sessionService);

    if (di.serviceLocator.isRegistered<ProviderDiscoveryService>()) {
      di.serviceLocator.unregister<ProviderDiscoveryService>();
    }
    di.serviceLocator.registerSingleton<ProviderDiscoveryService>(providerDiscovery);

    if (di.serviceLocator.isRegistered<GatewayControlService>()) {
      di.serviceLocator.unregister<GatewayControlService>();
    }
    di.serviceLocator.registerSingleton<GatewayControlService>(gatewayService);

    if (di.serviceLocator.isRegistered<SettingsPreferenceService>()) {
      di.serviceLocator.unregister<SettingsPreferenceService>();
    }
    di.serviceLocator.registerSingleton<SettingsPreferenceService>(_FakeSettingsPreferenceService());
  });

  tearDown(() {
    di.serviceLocator.unregister<ChannelService>();
    di.serviceLocator.unregister<SessionService>();
    di.serviceLocator.unregister<ProviderDiscoveryService>();
    di.serviceLocator.unregister<GatewayControlService>();
    di.serviceLocator.unregister<SettingsPreferenceService>();
  });

  group('Cockpit screens', () {
    testWidgets('ChannelsScreen renders without crashing', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: ChannelsScreen()),
      );
      // Allow async initState loading to complete
      await tester.pump(const Duration(seconds: 2));
      await tester.pump();
      expect(find.byType(ChannelsScreen), findsOneWidget);
    });

    testWidgets('SessionsScreen renders without crashing', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: SessionsScreen()),
      );
      // Allow async initState loading to complete
      await tester.pump(const Duration(seconds: 2));
      await tester.pump();
      expect(find.byType(SessionsScreen), findsOneWidget);
    });

    testWidgets('InstancesScreen renders without crashing', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: InstancesScreen()),
      );
      // Allow async initState loading to complete
      await tester.pump(const Duration(seconds: 2));
      await tester.pump();
      expect(find.byType(InstancesScreen), findsOneWidget);
    });
  });
}