import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pistisai/services/brain_sync_service.dart';
import 'package:pistisai/services/cloud_connector_service.dart';
import 'package:pistisai/services/settings_preference_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/mock_services.dart';

/// Local-only by default: unless the user chooses the cloud, the app
/// sends nothing to the hosted service — no device registration, no
/// heartbeat, no device listing or revoke, no brain sync.
void main() {
  late List<http.BaseRequest> sent;
  late MockClient client;

  setUp(() {
    sent = [];
    client = MockClient((request) async {
      sent.add(request);
      return http.Response('{"data":[]}', 200);
    });
  });

  CloudConnectorService connector({Future<bool> Function()? cloudAllowed}) =>
      CloudConnectorService(
        authService: createMockAuthService(),
        httpClient: client,
        baseUrl: 'https://api.example.com',
        cloudAllowed: cloudAllowed,
      );

  test('cloud services are off by default', () async {
    SharedPreferences.setMockInitialValues({});
    expect(await SettingsPreferenceService().isCloudServicesEnabled(), isFalse);
  });

  group('cloud connector', () {
    for (final entry in <String, Future<bool> Function()?>{
      'no consent check wired': null,
      'cloud not chosen': () async => false,
      'consent check fails': () async => throw StateError('prefs'),
    }.entries) {
      test(
          '${entry.key}: registration, heartbeat and device calls send '
          'nothing', () async {
        final c = connector(cloudAllowed: entry.value);

        expect(await c.registerAndStart(), isFalse);
        expect(c.status, CloudConnectionStatus.disconnected);
        await expectLater(c.listDevices(), throwsStateError);
        await expectLater(c.revokeDevice('d1'), throwsStateError);

        expect(sent, isEmpty);
      });
    }

    test('when the user chose the cloud, device calls go out', () async {
      final c = connector(cloudAllowed: () async => true);
      await c.listDevices();
      expect(sent, hasLength(1));
      expect(sent.single.url.host, 'api.example.com');
    });
  });

  group('brain sync', () {
    test('cloud not chosen: sync sends nothing', () async {
      await http.runWithClient(() async {
        final sync = BrainSyncService.forTest(cloudAllowed: () async => false);
        final result = await sync.sync();
        expect(result.success, isFalse);
        expect(result.error, 'Cloud services are off');
      }, () => client);
      expect(sent, isEmpty);
    });

    test('no consent check wired: sync sends nothing', () async {
      await http.runWithClient(() async {
        await BrainSyncService.forTest().sync();
      }, () => client);
      expect(sent, isEmpty);
    });
  });
}
