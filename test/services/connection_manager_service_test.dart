import 'package:pistisai/services/connection_manager_service.dart';
import 'package:pistisai/services/hermes/hermes_streaming_service.dart';
import 'package:pistisai/services/openclaw_manager/gateway_control_service.dart';
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
        openclawGatewayService: GatewayControlService(
          SettingsPreferenceService(),
        ),
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

    test('Hermes selection exposes the runtime streaming service', () {
      service.configureHermesRuntime(url: 'http://127.0.0.1:8642');
      service.setPreferredConnectionType(ConnectionType.hermes);

      expect(service.activeBackend, BackendType.hermes);
      expect(service.preferredConnectionType, 'hermes');
      expect(service.getStreamingService(), isNotNull);
    });

    test(
        'legacy local selection clears the runtime instead of selecting a model provider',
        () {
      service.configureHermesRuntime(url: 'http://127.0.0.1:8642');
      service.setPreferredConnectionType(ConnectionType.hermes);

      service.setPreferredConnectionType(ConnectionType.local);

      expect(service.activeBackend, isNull);
      expect(service.getStreamingService(), isNull);
    });
  });
}
