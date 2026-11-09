import 'package:flutter_test/flutter_test.dart';
import 'package:pistisai/models/provider_configuration.dart';

void main() {
  group('ProviderInfo Hermes URL', () {
    test('url keeps the Hermes API port; baseUrl strips it', () {
      const info = ProviderInfo(
        id: 'hermes_discovered',
        name: 'Hermes Agent',
        type: ProviderType.hermes,
        url: 'http://127.0.0.1:8642',
        isLocal: true,
        isAvailable: true,
        role: ProviderRole.agentRuntime,
      );

      expect(info.url, 'http://127.0.0.1:8642');
      // Legacy host-only getter used by Ollama-style baseUrl+port pairs.
      expect(info.baseUrl, 'http://127.0.0.1');
      expect(info.port, 8642);
    });

    test('HermesProviderConfiguration is valid with full URL including port',
        () {
      final config = HermesProviderConfiguration(
        providerId: 'hermes_discovered',
        baseUrl: 'http://127.0.0.1:8642',
      );
      expect(config.isValid(), isTrue);
    });
  });
}
