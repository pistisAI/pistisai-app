import 'package:flutter_test/flutter_test.dart';
import 'package:pistisai/config/app_config.dart';
import 'package:pistisai/services/hermes/hermes_endpoint_resolver.dart';

void main() {
  group('HermesEndpointResolver', () {
    test('default port with /health wins over a later desktop port', () async {
      final calls = <Uri>[];
      final resolver = HermesEndpointResolver(
        probe: (Uri uri) async {
          calls.add(uri);
          if (uri.port == 8642 && uri.path == '/health') {
            return 200;
          }
          return null;
        },
        listServePorts: () async => <int>[51910],
      );

      final result = await resolver.resolve();

      expect(result.isAgentApi, isTrue);
      expect(result.url, AppConfig.defaultHermesUrl);
      expect(calls.any((Uri uri) => uri.port == 51910), isFalse);
    });

    test('uses a hermes serve port when its agent API answers', () async {
      final resolver = HermesEndpointResolver(
        probe: (Uri uri) async {
          if (uri.port == 51910 && uri.path == '/health') {
            return 200;
          }
          return null;
        },
        listServePorts: () async => <int>[51910],
      );

      final result = await resolver.resolve();

      expect(result.isAgentApi, isTrue);
      expect(result.url, 'http://127.0.0.1:51910');
    });

    test('/v1/models counts as the agent API when /health is closed', () async {
      final resolver = HermesEndpointResolver(
        probe: (Uri uri) async {
          if (uri.port == 8642 && uri.path == '/v1/models') {
            return 200;
          }
          return null;
        },
        listServePorts: () async => <int>[],
      );

      final result = await resolver.resolve();

      expect(result.kind, HermesEndpointKind.agentApi);
      expect(result.url, AppConfig.defaultHermesUrl);
    });

    test('desktop /api/health is not a connection and names the port', () async {
      final resolver = HermesEndpointResolver(
        probe: (Uri uri) async {
          if (uri.port == 51910 && uri.path == '/api/health') {
            return 200;
          }
          return null;
        },
        listServePorts: () async => <int>[51910],
      );

      final result = await resolver.resolve();

      expect(result.isAgentApi, isFalse);
      expect(result.kind, HermesEndpointKind.desktopDashboard);
      expect(result.url, 'http://127.0.0.1:51910');
      expect(result.message, contains('51910'));
      expect(result.message, contains('agent API'));
    });

    test('no listeners falls back to the default URL', () async {
      final resolver = HermesEndpointResolver(
        probe: (Uri uri) async => null,
        listServePorts: () async => <int>[],
      );

      final result = await resolver.resolve();

      expect(result.kind, HermesEndpointKind.unreachable);
      expect(result.isAgentApi, isFalse);
      expect(result.url, AppConfig.defaultHermesUrl);
    });

    test('a 200 response from the bare URL is not a connection', () async {
      final resolver = HermesEndpointResolver(
        probe: (Uri uri) async {
          if (uri.path.isEmpty || uri.path == '/') {
            return 200;
          }
          return null;
        },
        listServePorts: () async => <int>[51910],
      );

      final result = await resolver.classify('http://127.0.0.1:51910');

      expect(result.isAgentApi, isFalse);
      expect(result.kind, HermesEndpointKind.unreachable);
    });
  });

  test('parseHermesServePortLines keeps unique listen ports', () {
    expect(
      parseHermesServePortLines('51910\r\n8642\r\n51910\r\n0\r\nnot-a-port\n'),
      <int>[51910, 8642],
    );
  });
}
