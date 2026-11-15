/// Policy for optional third-party cloud LLM and speech outbound calls.
///
/// Default product behaviour is local-only. Cloud adapters (Zhipu/GLM,
/// Moonshot/Kimi, Google Gemini) and Microsoft online speech stay available
/// in the codebase but must not run until the user grants explicit consent.
class CloudOutboundPolicy {
  CloudOutboundPolicy._();

  static const Set<String> cloudLlmProviderNames = {
    'zhipu',
    'moonshot',
    'google',
  };

  static bool isCloudLlmProvider(String name) =>
      cloudLlmProviderNames.contains(name);

  /// Returns provider id → API key for cloud adapters that may be registered.
  ///
  /// Empty when [consentGranted] is false, even if compile-time keys exist.
  static Map<String, String> selectCloudProviders({
    required bool consentGranted,
    required String glmKey,
    required String geminiKey,
    required String kimiKey,
  }) {
    if (!consentGranted) {
      return const <String, String>{};
    }
    return <String, String>{
      if (glmKey.isNotEmpty) 'zhipu': glmKey,
      if (geminiKey.isNotEmpty) 'google': geminiKey,
      if (kimiKey.isNotEmpty) 'moonshot': kimiKey,
    };
  }
}
