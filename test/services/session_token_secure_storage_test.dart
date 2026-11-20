import 'package:flutter_test/flutter_test.dart';
import 'package:pistisai/database/local_brain_key_store.dart';
import 'package:pistisai/services/session_storage_service.dart';
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

/// Exposes private session-token helpers for storage-contract tests.
class _TestSessionStorage extends SessionStorageService {
  _TestSessionStorage({super.secureVault});

  Future<void> storeForTest(String token) => storeSessionTokenForTest(token);

  Future<String?> readStoredForTest() => readStoredSessionTokenForTest();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  test('session token is stored in the secure vault, not SharedPreferences',
      () async {
    final vault = _MemoryVault();
    final sessions = _TestSessionStorage(secureVault: vault);

    await sessions.storeForTest('session-token-secret');

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('session_token'), isNull);
    expect(vault.store['session_token'], 'session-token-secret');
    expect(await sessions.readStoredForTest(), 'session-token-secret');
  });

  test('migrates session token from SharedPreferences into the vault', () async {
    SharedPreferences.setMockInitialValues({
      'session_token': 'legacy-session-token',
    });
    final vault = _MemoryVault();
    final sessions = _TestSessionStorage(secureVault: vault);

    expect(await sessions.readStoredForTest(), 'legacy-session-token');
    expect(vault.store['session_token'], 'legacy-session-token');

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('session_token'), isNull);
  });
}
