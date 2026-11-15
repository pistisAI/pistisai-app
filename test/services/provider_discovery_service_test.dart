import 'package:flutter_test/flutter_test.dart';
import 'package:pistisai/models/provider_configuration.dart';
import 'package:pistisai/services/hermes/hermes_endpoint_resolver.dart';
import 'package:pistisai/services/provider_discovery_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Hermes resolver reports agent API when /health answers', () async {
    final resolver = HermesEndpointResolver(
      probe: (uri) async {
        if (uri.path == '/health' || uri.path == '/v1/models') {
          return 200;
        }
        return null;
      },
      listServePorts: () async => <int>[],
    );

    final resolution = await resolver.resolve(
      savedUrl: 'http://127.0.0.1:18642',
    );
    expect(resolution.isAgentApi, isTrue);
    expect(resolution.url, 'http://127.0.0.1:18642');
  });

  test('graceful degradation when Hermes probes fail', () async {
    final resolver = HermesEndpointResolver(
      probe: (_) async => null,
      listServePorts: () async => <int>[],
    );
    final resolution = await resolver.resolve(
      savedUrl: 'http://127.0.0.1:9',
    );
    expect(resolution.isAgentApi, isFalse);
    expect(resolution.kind, HermesEndpointKind.unreachable);

    final discovery = ProviderDiscoveryService(hermesResolver: resolver);
    final runtimes = await discovery.scanForAgentRuntimes();
    expect(
      runtimes.where((p) => p.type == ProviderType.hermes),
      isEmpty,
    );
  });
}
