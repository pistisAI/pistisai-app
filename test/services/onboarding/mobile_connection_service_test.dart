import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pistisai/config/app_config.dart';
import 'package:pistisai/database/local_brain_key_store.dart';
import 'package:pistisai/services/hermes/hermes_streaming_service.dart';
import 'package:pistisai/services/onboarding/mobile_connection_service.dart';
import 'package:pistisai/services/settings_preference_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MemoryVault implements LocalBrainKeyVault {
  final Map<String, String> store = {};

  @override
  Future<String?> read(String key) async => store[key];

  @override
  Future<void> write(String key, String value) async {
    store[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    store.remove(key);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('normalizeHubHost', () {
    test('accepts a Tailscale CGNAT address', () {
      expect(
        MobileConnectionService.normalizeHubHost('100.64.1.20'),
        '100.64.1.20',
      );
    });

    test('strips scheme, port, and path from a full URL', () {
      expect(
        MobileConnectionService.normalizeHubHost(
          'http://pc.tailnet.ts.net:8642/health',
        ),
        'pc.tailnet.ts.net',
      );
    });

    test('rejects blank input', () {
      expect(MobileConnectionService.normalizeHubHost('   '), isNull);
    });
  });

  group('isAndroidTestRigLoopbackHost', () {
    test('recognizes emulator and local Docker bridge hosts', () {
      expect(MobileConnectionService.isAndroidTestRigLoopbackHost('10.0.2.2'), isTrue);
      expect(MobileConnectionService.isAndroidTestRigLoopbackHost('127.0.0.1'), isTrue);
      expect(
        MobileConnectionService.isAndroidTestRigLoopbackHost('host.docker.internal'),
        isTrue,
      );
      expect(MobileConnectionService.isAndroidTestRigLoopbackHost('192.168.1.1'), isFalse);
    });
  });

  group('isAllowedTailscaleHubHost', () {
    test('allows MagicDNS and CGNAT, rejects LAN and public hosts', () {
      expect(
        MobileConnectionService.isAllowedTailscaleHubHost(
          'pc.tailnet.ts.net',
        ),
        isTrue,
      );
      expect(
        MobileConnectionService.isAllowedTailscaleHubHost('100.64.1.20'),
        isTrue,
      );
      expect(
        MobileConnectionService.isAllowedTailscaleHubHost('100.127.0.1'),
        isTrue,
      );
      expect(
        MobileConnectionService.isAllowedTailscaleHubHost('192.168.1.20'),
        isFalse,
      );
      expect(
        MobileConnectionService.isAllowedTailscaleHubHost('8.8.8.8'),
        isFalse,
      );
      expect(
        MobileConnectionService.isAllowedTailscaleHubHost('evil.example.com'),
        isFalse,
      );
      expect(
        MobileConnectionService.isAllowedTailscaleHubHost('desktop'),
        isFalse,
      );
    });
  });

  group('MobileConnectionService', () {
    test('shows the connection screen until a mode is saved', () async {
      final service = MobileConnectionService();
      expect(await service.shouldShowConnectionScreen(), isTrue);
    });

    test('connectViaPistisaiApp persists cloud mode and hides the screen',
        () async {
      final service = MobileConnectionService();
      await service.connectViaPistisaiApp();

      expect(service.mode, MobileConnectionMode.pistisaiApp);
      expect(service.requireCloudLogin, isTrue);
      expect(await service.shouldShowConnectionScreen(), isFalse);
    });

    test('connectViaTailscaleHub saves Hermes URL when the desktop hub answers',
        () async {
      final hermes = HermesStreamingService();
      final settings = SettingsPreferenceService(secureVault: _MemoryVault());
      final service = MobileConnectionService(
        settings: settings,
        hermesStreamingService: hermes,
        httpGet: (uri) async {
          if (uri.path == AppConfig.hubPath) {
            return http.Response('{"role":"primary_hub"}', 200);
          }
          return http.Response('nope', 404);
        },
      );

      final result = await service.connectViaTailscaleHub(
        '100.64.1.20',
        hubToken: 'hub-token',
      );

      expect(result.success, isTrue);
      expect(result.foundPrimaryHub, isTrue);
      expect(result.hermesUrl, 'http://100.64.1.20:1337');
      expect(hermes.baseUrl, 'http://100.64.1.20:1337');
      expect(await settings.getHermesUrl(), 'http://100.64.1.20:1337');
      expect(service.mode, MobileConnectionMode.tailscaleHub);
      expect(await service.shouldShowConnectionScreen(), isFalse);
      hermes.dispose();
    });

    test('stores the hub token as the bearer key when connecting', () async {
      final vault = _MemoryVault();
      final settings = SettingsPreferenceService(secureVault: vault);
      final service = MobileConnectionService(
        settings: settings,
        httpGet: (uri) async {
          if (uri.path == AppConfig.hubPath) {
            return http.Response('{"role":"primary_hub"}', 200);
          }
          return http.Response('nope', 404);
        },
      );

      final result = await service.connectViaTailscaleHub(
        '100.64.1.20',
        hubToken: '  hub-token-123  ',
      );

      expect(result.success, isTrue);
      expect(vault.store['settings_hermes_api_key'], 'hub-token-123');
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('settings_hermes_api_key'), isNull);
    });

    test('hub unreachable message points at the desktop remote access setting',
        () async {
      final service = MobileConnectionService(
        httpGet: (uri) async => throw Exception('unreachable'),
      );

      final result = await service.probeHub('pc.tailnet.ts.net');
      expect(result.success, isFalse);
      expect(result.message, contains('Remote hub access'));
      expect(result.message, contains('restart'));
    });

    test('refuses direct Hermes when the desktop hub path is absent', () async {
      final service = MobileConnectionService(
        httpGet: (uri) async {
          if (uri.path == '/health') {
            return http.Response('OK', 200);
          }
          throw Exception('hub down');
        },
      );

      final result = await service.probeHub('pc.tailnet.ts.net');
      expect(result.success, isFalse);
      expect(result.foundPrimaryHub, isFalse);
      expect(result.hermesUrl, 'http://pc.tailnet.ts.net:1337');
    });

    test('does not probe a non-tailnet host even if it answers /health',
        () async {
      var probed = false;
      final service = MobileConnectionService(
        httpGet: (uri) async {
          probed = true;
          return http.Response('OK', 200);
        },
      );

      final result = await service.probeHub('192.168.1.20');
      expect(result.success, isFalse);
      expect(probed, isFalse);
      expect(result.message, contains('.ts.net'));
    });

    test('blank hub token does not finish pairing or hide the connection screen',
        () async {
      final service = MobileConnectionService(
        httpGet: (uri) async {
          if (uri.path == AppConfig.hubPath) {
            return http.Response('{"role":"primary_hub"}', 200);
          }
          return http.Response('nope', 404);
        },
      );

      final result = await service.connectViaTailscaleHub(
        '100.64.1.20',
        hubToken: '   ',
      );

      expect(result.success, isFalse);
      expect(result.message, contains('token'));
      expect(await service.shouldShowConnectionScreen(), isTrue);
    });

    test('hub token reaches the live Hermes client without a restart',
        () async {
      String? seenAuthorization;
      final client = MockClient((request) async {
        seenAuthorization = request.headers['authorization'];
        return http.Response('{"data":[]}', 200);
      });
      final hermes = HermesStreamingService(client: client);
      final service = MobileConnectionService(
        settings: SettingsPreferenceService(secureVault: _MemoryVault()),
        hermesStreamingService: hermes,
        httpGet: (uri) async {
          if (uri.path == AppConfig.hubPath) {
            return http.Response('{"role":"primary_hub"}', 200);
          }
          return http.Response('nope', 404);
        },
      );

      final result = await service.connectViaTailscaleHub(
        '100.64.1.20',
        hubToken: 'hub-token-123',
      );

      expect(result.success, isTrue);
      await hermes.getAvailableModels();
      expect(seenAuthorization, 'Bearer hub-token-123');
      hermes.dispose();
    });
  });
}
