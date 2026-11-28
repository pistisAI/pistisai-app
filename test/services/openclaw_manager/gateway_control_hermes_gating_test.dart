import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pistisai/services/openclaw_manager/gateway_control_service.dart';
import 'package:pistisai/services/settings_preference_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('GatewayControlService is opt-in (#1042)', () {
    test('never runs the openclaw CLI on its own', () async {
      final calls = <List<String>>[];
      final service = GatewayControlService(
        SettingsPreferenceService(),
        processRunner: (exe, args) async {
          calls.add([exe, ...args]);
          return ProcessResult(0, 0, 'running', '');
        },
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(calls, isEmpty);
      expect(service.state, GatewayState.unknown);
      service.dispose();
    });

    test('runs the CLI only when a caller asks for status', () async {
      final calls = <List<String>>[];
      final service = GatewayControlService(
        SettingsPreferenceService(),
        processRunner: (exe, args) async {
          calls.add([exe, ...args]);
          return ProcessResult(0, 1, '', 'not installed');
        },
      );
      await service.checkStatus();
      expect(calls, [
        ['openclaw', 'gateway', 'status', '--json'],
      ]);
      expect(service.state, GatewayState.stopped);
      service.dispose();
    });

    test('the service locator neither registers nor wires it to Hermes', () {
      // setupCoreServices needs the full desktop graph, so check the source:
      // a registration or a connection-manager hook would spawn the CLI on
      // every Hermes connect.
      final locator = File('lib/di/locator.dart').readAsStringSync();
      expect(locator, isNot(contains('GatewayControlService(')));
      expect(locator, isNot(contains('<GatewayControlService>')));
      expect(
        locator,
        isNot(contains('gatewayControlService.setConnectionManager')),
      );
    });
  });
}
