import 'package:pistisai/services/connection_manager_service.dart';
import 'package:pistisai/services/hermes/hermes_streaming_service.dart';
import 'package:pistisai/services/hub/client_connectivity.dart';
import 'package:pistisai/services/settings_preference_service.dart'
    hide BackendType;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('ConnectionManagerService runtime session', () {
    late ConnectionManagerService service;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      service = ConnectionManagerService(
        hermesStreamingService: HermesStreamingService(),
        settingsPreferenceService: SettingsPreferenceService(),
        autoDetectOnInitialize: false,
      );
      await service.initialize();
    });

    tearDown(() {
      service.dispose();
    });

    test('sendChatMessage returns immediately when no runtime is connected',
        () async {
      expect(service.isConnected, isFalse);
      final started = DateTime.now();
      final reply = await service.sendChatMessage(
        model: 'default',
        message: 'hello',
      );
      expect(reply, isNull);
      expect(DateTime.now().difference(started).inSeconds, lessThan(2));
    });

    test('Hermes selection exposes the runtime streaming service', () async {
      await service.configureHermesRuntime(url: 'http://127.0.0.1:8642');
      service.setPreferredConnectionType(ConnectionType.hermes);

      expect(service.activeBackend, BackendType.hermes);
      expect(service.preferredConnectionType, 'hermes');
      expect(service.getStreamingService(), isNotNull);
    });

    test(
        'legacy local selection clears the runtime instead of selecting a model provider',
        () async {
      await service.configureHermesRuntime(url: 'http://127.0.0.1:8642');
      service.setPreferredConnectionType(ConnectionType.hermes);

      service.setPreferredConnectionType(ConnectionType.local);

      expect(service.activeBackend, isNull);
      expect(service.getStreamingService(), isNull);
    });
  });

  test('web role refuses loopback Hermes and joins a hub URL', () async {
    SharedPreferences.setMockInitialValues({
      'settings_client_install_role': 'web',
    });
    final hermes = HermesStreamingService(role: ClientInstallRole.web);
    final service = ConnectionManagerService(
      hermesStreamingService: hermes,
      settingsPreferenceService: SettingsPreferenceService(),
      autoDetectOnInitialize: false,
    );
    await service.initialize();

    await service.configureHermesRuntime(url: 'http://127.0.0.1:8642');
    expect(service.lastError, directHermesRefusal);
    expect(service.isConnected, isFalse);
    expect(hermes.refusedDirectHermes, isTrue);

    await service.configureHermesRuntime(url: 'http://100.64.1.20:1337');
    service.setPreferredConnectionType(ConnectionType.hermes);
    final streaming = service.getStreamingService();
    expect(streaming, isA<HermesStreamingService>());
    expect((streaming as HermesStreamingService).baseUrl,
        'http://100.64.1.20:1337');
    expect(streaming.reachesHermesViaHub, isTrue);
    expect(await SettingsPreferenceService().getHubUrl(),
        'http://100.64.1.20:1337');
    expect(await SettingsPreferenceService().getHermesUrl(), isNull);

    service.dispose();
    hermes.dispose();
  });

  test('a remote Hermes URL on desktop joins the hub on the same host',
      () async {
    SharedPreferences.setMockInitialValues({
      'settings_hermes_url': 'http://100.64.1.20:8642',
    });
    final hermes = HermesStreamingService();
    final service = ConnectionManagerService(
      hermesStreamingService: hermes,
      settingsPreferenceService: SettingsPreferenceService(),
      autoDetectOnInitialize: false,
    );
    await service.initialize();

    expect(service.installRole, ClientInstallRole.secondaryDesktop);
    expect(hermes.baseUrl, 'http://100.64.1.20:1337');
    expect(hermes.reachesHermesViaHub, isTrue);
    expect(hermes.refusedDirectHermes, isFalse);

    service.dispose();
    hermes.dispose();
  });

  test('web with Hermes enabled and no hub does not dial loopback', () async {
    SharedPreferences.setMockInitialValues({
      'settings_client_install_role': 'web',
      'settings_hermes_enabled': true,
    });
    final hermes = HermesStreamingService(role: ClientInstallRole.web);
    final service = ConnectionManagerService(
      hermesStreamingService: hermes,
      settingsPreferenceService: SettingsPreferenceService(),
      autoDetectOnInitialize: false,
    );
    await service.initialize();

    expect(service.installRole, ClientInstallRole.web);
    expect(service.activeBackend, isNull);
    expect(service.activeRuntimeClient, isNull);
    expect(service.getStreamingService(), isNull);
    expect(service.isConnected, isFalse);
    expect(service.lastError, directHermesRefusal);
    expect(hermes.baseUrl, isNot(contains(':1337')));
    expect(hermes.refusedDirectHermes, isTrue);

    final reached = await hermes.testConnection();
    expect(reached, isFalse);

    service.dispose();
    hermes.dispose();
  });
}
