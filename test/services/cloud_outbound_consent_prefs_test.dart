import 'package:flutter_test/flutter_test.dart';
import 'package:pistisai/services/settings_preference_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('cloud LLM providers are opt-in and off by default', () async {
    final settings = SettingsPreferenceService();

    expect(await settings.isCloudLlmProvidersEnabled(), isFalse);

    await settings.setCloudLlmProvidersEnabled(true);
    expect(await settings.isCloudLlmProvidersEnabled(), isTrue);

    await settings.setCloudLlmProvidersEnabled(false);
    expect(await settings.isCloudLlmProvidersEnabled(), isFalse);
  });

  test('Microsoft speech is opt-in and off by default', () async {
    final settings = SettingsPreferenceService();

    expect(await settings.isMicrosoftSpeechEnabled(), isFalse);

    await settings.setMicrosoftSpeechEnabled(true);
    expect(await settings.isMicrosoftSpeechEnabled(), isTrue);

    await settings.setMicrosoftSpeechEnabled(false);
    expect(await settings.isMicrosoftSpeechEnabled(), isFalse);
  });
}
