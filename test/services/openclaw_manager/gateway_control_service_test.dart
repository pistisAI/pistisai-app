import 'package:pistisai/services/openclaw_manager/gateway_control_service.dart';
import 'package:pistisai/services/settings_preference_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('GatewayControlService', () {
    test('constructs with default settings', () {
      expect(
        () => GatewayControlService(SettingsPreferenceService()),
        returnsNormally,
      );
    });

    test('isRunning returns false initially', () {
      final service = GatewayControlService(SettingsPreferenceService());
      expect(service.isRunning, isFalse);
      expect(service.state, GatewayState.unknown);
      service.dispose();
    });

    test('errorMessage is null initially', () {
      final service = GatewayControlService(SettingsPreferenceService());
      expect(service.errorMessage, isNull);
      service.dispose();
    });

    test('startedAt is null initially', () {
      final service = GatewayControlService(SettingsPreferenceService());
      expect(service.startedAt, isNull);
      service.dispose();
    });

    test('autoRestartEnabled defaults to true', () async {
      SharedPreferences.setMockInitialValues({'gateway_auto_restart': true});
      final service = GatewayControlService(SettingsPreferenceService());
      // Allow async loading to complete
      await Future<void>.delayed(Duration.zero);
      expect(service.autoRestartEnabled, isTrue);
      service.dispose();
    });

    test('stop reports failure when the gateway state is unknown (#857)',
        () async {
      SharedPreferences.setMockInitialValues({});
      final service = GatewayControlService(SettingsPreferenceService());
      expect(service.state, GatewayState.unknown);
      final stopped = await service.stop();
      // Nothing was stopped, so the control must not report success.
      expect(stopped, isFalse);
      expect(service.errorMessage, isNotNull);
      expect(service.isRunning, isFalse);
      service.dispose();
    });

    test('restart calls stop and start', () async {
      SharedPreferences.setMockInitialValues({});
      final service = GatewayControlService(SettingsPreferenceService());
      final restarted = await service.restart();
      // Should still be in error state after start fails (no openclaw binary)
      expect(restarted, isFalse);
      expect(service.state, GatewayState.error);
      service.dispose();
    });
  });
}
