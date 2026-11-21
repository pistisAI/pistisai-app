import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pistisai/config/app_config.dart';
import 'package:pistisai/services/hermes/hermes_endpoint_resolver.dart';
import 'package:pistisai/services/hermes/hermes_local_agent_api.dart';

void main() {
  group('upsertApiServerEnv', () {
    test('keeps an existing key and turns the API server on', () {
      const existing = 'OTHER=1\r\nAPI_SERVER_KEY=abcdefghijklmnop\r\n';

      final updated = upsertApiServerEnv(
        existing,
        generateKey: () => 'psk_should_not_be_used',
      );

      expect(updated.key, 'abcdefghijklmnop');
      expect(updated.content, contains('API_SERVER_KEY=abcdefghijklmnop'));
      expect(updated.content, contains('API_SERVER_ENABLED=true'));
      expect(updated.content, isNot(contains('psk_should_not_be_used')));
    });

    test('writes a preferred key when none is stored', () {
      final updated = upsertApiServerEnv(
        '',
        preferredKey: 'test_hermes_api_key',
        generateKey: () => 'psk_generated_key_value',
      );

      expect(updated.key, 'test_hermes_api_key');
      expect(updated.content, contains('API_SERVER_KEY=test_hermes_api_key'));
      expect(updated.content, contains('API_SERVER_ENABLED=true'));
    });
  });

  group('HermesLocalAgentApi.ensure', () {
    test('does not restart the gateway when the agent API is already up',
        () async {
      var restarted = false;
      final api = HermesLocalAgentApi(
        readHome: () => 'unused',
        restartGateway: (String home) async {
          restarted = true;
          return true;
        },
      );
      final resolver = HermesEndpointResolver(
        probe: (Uri uri) async {
          if (uri.port == 8642 && uri.path == '/health') {
            return 200;
          }
          return null;
        },
        listServePorts: () async => <int>[51910],
      );

      final ready = await api.ensure(resolver);

      expect(restarted, isFalse);
      expect(ready.resolution.isAgentApi, isTrue);
      expect(ready.resolution.url, AppConfig.defaultHermesUrl);
    });

    test('restarts the gateway and then uses port 8642', () async {
      final home = Directory.systemTemp.createTempSync('hermes-api-test');
      addTearDown(() => home.deleteSync(recursive: true));
      var started = false;
      final api = HermesLocalAgentApi(
        readHome: () => home.path,
        restartGateway: (String path) async {
          started = true;
          return true;
        },
        generateKey: () => 'test_hermes_api_key',
      );
      final resolver = HermesEndpointResolver(
        probe: (Uri uri) async {
          if (started && uri.port == 8642 && uri.path == '/health') {
            return 200;
          }
          if (uri.port == 51910 && uri.path == '/api/health') {
            return 200;
          }
          return null;
        },
        listServePorts: () async => <int>[51910],
      );

      final ready = await api.ensure(resolver);

      expect(started, isTrue);
      expect(ready.resolution.isAgentApi, isTrue);
      expect(ready.resolution.url, AppConfig.defaultHermesUrl);
      expect(ready.apiKey, 'test_hermes_api_key');
      final envFile = File('${home.path}${Platform.pathSeparator}.env');
      final env = envFile.readAsStringSync();
      expect(env, contains('API_SERVER_KEY=test_hermes_api_key'));
      expect(env, contains('API_SERVER_ENABLED=true'));
      if (!Platform.isWindows) {
        final mode = envFile.statSync().mode & 0x1FF;
        expect(mode & 0x3F, 0,
            reason: 'Hermes .env must not be group/world readable');
      }
    });
  });

  group('writeHermesApiServerKey permissions', () {
    test('creates .env with owner-only permissions', () {
      final home = Directory.systemTemp.createTempSync('hermes-env-mode-');
      addTearDown(() => home.deleteSync(recursive: true));

      writeHermesApiServerKey(
        home.path,
        preferredKey: 'test_hermes_api_key_perms',
      );

      final envFile = File('${home.path}${Platform.pathSeparator}.env');
      expect(envFile.existsSync(), isTrue);
      if (!Platform.isWindows) {
        final mode = envFile.statSync().mode & 0x1FF;
        expect(mode & 0x3F, 0,
            reason: 'Hermes .env must not be group/world readable');
      }
    });
  });

  group('writeHermesApiServerKey on an existing world-readable .env', () {
    test('ends owner-only and leaves no temp file', () {
      if (Platform.isWindows) return;
      final home = Directory.systemTemp.createTempSync('hermes-env-mode2-');
      addTearDown(() => home.deleteSync(recursive: true));
      final envFile = File('${home.path}${Platform.pathSeparator}.env');
      envFile.writeAsStringSync('OTHER=1\n');
      Process.runSync('chmod', ['644', envFile.path]);

      writeHermesApiServerKey(home.path, preferredKey: 'k2');

      expect(envFile.statSync().mode & 0x3F, 0);
      expect(envFile.readAsStringSync(), contains('OTHER=1'));
      expect(
        home.listSync().map((e) => e.path).where((p) => p.contains('.tmp-')),
        isEmpty,
      );
    });
  });
}
