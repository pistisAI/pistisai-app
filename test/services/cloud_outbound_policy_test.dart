import 'package:flutter_test/flutter_test.dart';
import 'package:pistisai/services/cloud_outbound_policy.dart';

void main() {
  group('CloudOutboundPolicy', () {
    test('treats zhipu, moonshot, and google as cloud LLM providers', () {
      expect(CloudOutboundPolicy.isCloudLlmProvider('zhipu'), isTrue);
      expect(CloudOutboundPolicy.isCloudLlmProvider('moonshot'), isTrue);
      expect(CloudOutboundPolicy.isCloudLlmProvider('google'), isTrue);
      expect(CloudOutboundPolicy.isCloudLlmProvider('hermes'), isFalse);
      expect(CloudOutboundPolicy.isCloudLlmProvider('ollama'), isFalse);
    });

    test('omits cloud providers when consent is not granted', () {
      final registered = CloudOutboundPolicy.selectCloudProviders(
        consentGranted: false,
        glmKey: 'glm-key',
        geminiKey: 'gemini-key',
        kimiKey: 'kimi-key',
      );

      expect(registered, isEmpty);
    });

    test('includes only providers that have keys when consent is granted', () {
      final registered = CloudOutboundPolicy.selectCloudProviders(
        consentGranted: true,
        glmKey: 'glm-key',
        geminiKey: '',
        kimiKey: 'kimi-key',
      );

      expect(registered.keys.toSet(), {'zhipu', 'moonshot'});
    });

    test('still omits providers with empty keys when consent is granted', () {
      final registered = CloudOutboundPolicy.selectCloudProviders(
        consentGranted: true,
        glmKey: '',
        geminiKey: '',
        kimiKey: '',
      );

      expect(registered, isEmpty);
    });
  });
}
