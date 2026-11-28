// Issue #861: the phone can only reach the desktop hub when remote access is
// explicitly enabled. The opt-in is off by default and its bearer token is
// kept in the OS keystore, never in plaintext SharedPreferences.
import 'package:flutter_test/flutter_test.dart';
import 'package:pistisai/database/local_brain_key_store.dart';
import 'package:pistisai/services/router_server.dart';
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

  test('remote hub access is opt-in and persists', () async {
    final settings = SettingsPreferenceService(secureVault: _MemoryVault());
    expect(await settings.isRemoteHubAccessEnabled(), isFalse);

    await settings.setRemoteHubAccessEnabled(true);
    expect(await settings.isRemoteHubAccessEnabled(), isTrue);

    await settings.setRemoteHubAccessEnabled(false);
    expect(await settings.isRemoteHubAccessEnabled(), isFalse);
  });

  test('remote hub token is stored in the keystore, not SharedPreferences',
      () async {
    final vault = _MemoryVault();
    final settings = SettingsPreferenceService(secureVault: vault);

    await settings.setRemoteHubToken('hub-token-abc');

    expect(vault.store['settings_remote_hub_token'], 'hub-token-abc');
    expect(await settings.getRemoteHubToken(), 'hub-token-abc');
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('settings_remote_hub_token'), isNull);
  });

  test('generated hub token is URL-safe and gates private endpoints', () {
    final token = RouterServer.generateAuthSecret();
    expect(token, isNotEmpty);
    expect(token, matches(RegExp(r'^[A-Za-z0-9_-]+$')));
    expect(RouterServer.generateAuthSecret(), isNot(token));

    final decision = RouterServer.accessDecision(
      path: '/api/sessions',
      fromLoopback: false,
      authorizationHeader: 'Bearer $token',
      authSecret: token,
      host: 'pc.tailnet.ts.net',
      method: 'GET',
      allowRemoteAccess: true,
    );
    expect(decision, isNull);

    final missing = RouterServer.accessDecision(
      path: '/api/sessions',
      fromLoopback: false,
      authorizationHeader: null,
      authSecret: token,
      host: 'pc.tailnet.ts.net',
      method: 'GET',
      allowRemoteAccess: true,
    );
    expect(missing, isNotNull);
  });

  group('stable remote hub token (#981)', () {
    test('reuses the stored token without generating a new one', () async {
      final vault = _MemoryVault();
      final settings = SettingsPreferenceService(secureVault: vault);
      await settings.setRemoteHubToken('stable-token');

      final token = await settings.ensureRemoteHubToken(
        generate: () => throw StateError('must not generate'),
      );

      expect(token, 'stable-token');
    });

    test('does not overwrite the keystore after a transient read failure',
        () async {
      final vault = _ThrowingReadVault();
      final settings = SettingsPreferenceService(secureVault: vault);

      final token = await settings.ensureRemoteHubToken(
        generate: () => 'new-token',
      );

      expect(token, isNull);
      expect(vault.writes, isEmpty);
    });
  });
}

class _ThrowingReadVault implements LocalBrainKeyVault {
  final writes = <String>[];

  @override
  Future<String?> read(String key) async => throw StateError('keychain busy');

  @override
  Future<void> write(String key, String value) async {
    writes.add(key);
  }

  @override
  Future<void> delete(String key) async {}
}
