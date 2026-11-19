import 'package:flutter_test/flutter_test.dart';
import 'package:pistisai/database/local_brain_key_store.dart';
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

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  test('Hermes API key is stored in the secure vault, not SharedPreferences',
      () async {
    final vault = _MemoryVault();
    final settings = SettingsPreferenceService(secureVault: vault);

    await settings.setHermesApiKey('psk_test_secret_key');

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('settings_hermes_api_key'), isNull);
    expect(vault.store['settings_hermes_api_key'], 'psk_test_secret_key');
    expect(await settings.getHermesApiKey(), 'psk_test_secret_key');
  });

  test('migrates Hermes API key from SharedPreferences into the vault',
      () async {
    SharedPreferences.setMockInitialValues({
      'settings_hermes_api_key': 'psk_legacy_prefs_key',
    });
    final vault = _MemoryVault();
    final settings = SettingsPreferenceService(secureVault: vault);

    expect(await settings.getHermesApiKey(), 'psk_legacy_prefs_key');
    expect(vault.store['settings_hermes_api_key'], 'psk_legacy_prefs_key');

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('settings_hermes_api_key'), isNull);
  });
}
