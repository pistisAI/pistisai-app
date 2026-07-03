import 'package:flutter/foundation.dart';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'session_storage_service.dart';
import '../di/locator.dart' as di;

class TokenStorageService {
  static final _secureStorage = const FlutterSecureStorage();
  static encrypt.Encrypter? _encrypter;
  static encrypt.Key? _aesKey;
  static bool _secureStorageAvailable = true;
  static final Map<String, String> _memoryFallback = {};
  SessionStorageService? _sessionStorage;

  Future<void> init() async {
    // Try to get SessionStorageService from locator
    try {
      _sessionStorage = di.serviceLocator.get<SessionStorageService>();
    } catch (e) {
      debugPrint(
          '[TokenStorageService] SessionStorageService not found in locator');
    }

    await _initEncryption();
  }

  Future<void> _initEncryption() async {
    try {
      String? keyStr = await _secureStorage.read(key: 'auth_encryption_key');
      if (keyStr == null) {
        final key = encrypt.Key.fromSecureRandom(32);
        keyStr = key.base64;
        await _secureStorage.write(key: 'auth_encryption_key', value: keyStr);
      }

      _aesKey = encrypt.Key.fromBase64(keyStr);
      _encrypter = encrypt.Encrypter(encrypt.AES(_aesKey!));
      _secureStorageAvailable = true;
    } catch (e) {
      debugPrint(
          '[TokenStorageService] Secure storage unavailable, using in-memory fallback: $e');
      final key = encrypt.Key.fromSecureRandom(32);
      _aesKey = key;
      _encrypter = encrypt.Encrypter(encrypt.AES(key));
      _secureStorageAvailable = false;
    }
  }

  /// Encrypt value with a random IV, return "base64iv:base64ciphertext"
  String _encryptWithRandomIV(String plaintext) {
    final iv = encrypt.IV.fromSecureRandom(16);
    final encrypted = _encrypter!.encrypt(plaintext, iv: iv);
    return '${iv.base64}:${encrypted.base64}';
  }

  /// Decrypt a value stored as "base64iv:base64ciphertext"
  String _decryptWithIV(String stored) {
    final parts = stored.split(':');
    if (parts.length != 2) {
      throw FormatException('Invalid encrypted format');
    }
    final iv = encrypt.IV.fromBase64(parts[0]);
    return _encrypter!.decrypt64(parts[1], iv: iv);
  }

  Future<void> saveToken(String key, String value) async {
    // If we have an active session, sync to PostgreSQL
    if (_sessionStorage?.currentSession != null) {
      final session = _sessionStorage!.currentSession!;
      try {
        await _sessionStorage!.syncTokens(
          sessionToken: session.token,
          accessToken: key == 'access_token' ? value : session.accessToken,
          idToken: key == 'id_token' ? value : session.idToken,
          refreshToken: key == 'refresh_token' ? value : session.refreshToken,
        );
      } catch (e) {
        debugPrint(
            '[TokenStorageService] Failed to sync token $key to PostgreSQL: $e');
      }
    }

    if (_encrypter == null) await init();

    // Use memory fallback if secure storage unavailable
    if (!_secureStorageAvailable) {
      _memoryFallback['token_$key'] = value;
      return;
    }

    try {
      final encrypted = _encryptWithRandomIV(value);
      await _secureStorage.write(key: 'token_$key', value: encrypted);
    } catch (e) {
      debugPrint(
          '[TokenStorageService] Failed to write to secure storage, using memory fallback: $e');
      _memoryFallback['token_$key'] = value;
    }
  }

  Future<String?> getToken(String key) async {
    // Try to get from PostgreSQL session first
    if (_sessionStorage?.currentSession != null) {
      final session = _sessionStorage!.currentSession!;
      if (key == 'access_token') return session.accessToken;
      if (key == 'id_token') return session.idToken;
      if (key == 'refresh_token') return session.refreshToken;
    }

    if (_encrypter == null) await init();

    // Use memory fallback if secure storage unavailable
    if (!_secureStorageAvailable) {
      return _memoryFallback['token_$key'];
    }

    try {
      final encryptedStr = await _secureStorage.read(key: 'token_$key');
      if (encryptedStr == null) return null;

      return _decryptWithIV(encryptedStr);
    } catch (e) {
      debugPrint('[TokenStorageService] Decryption failed for key: $key - $e');
      return _memoryFallback['token_$key'];
    }
  }

  Future<void> deleteToken(String key) async {
    await _secureStorage.delete(key: 'token_$key');
  }

  Future<void> clearAll() async {
    // Clear known tokens
    await _secureStorage.delete(key: 'token_access_token');
    await _secureStorage.delete(key: 'token_id_token');
    await _secureStorage.delete(key: 'token_refresh_token');
  }

  // Multi-account support for Gmail/external integrations

  Future<void> saveTokens({
    required String provider,
    required String email,
    required String accessToken,
    String? idToken,
    String? refreshToken,
  }) async {
    if (_encrypter == null) await init();

    await _secureStorage.write(
        key: 'tokens_$provider:$email:access',
        value: _encryptWithRandomIV(accessToken));

    if (idToken != null) {
      await _secureStorage.write(
          key: 'tokens_$provider:$email:id',
          value: _encryptWithRandomIV(idToken));
    }

    if (refreshToken != null) {
      await _secureStorage.write(
          key: 'tokens_$provider:$email:refresh',
          value: _encryptWithRandomIV(refreshToken));
    }

    // Keep track of connected emails for this provider
    final existing = await getConnectedEmails(provider);
    if (!existing.contains(email)) {
      existing.add(email);
      await _secureStorage.write(
          key: 'emails_$provider', value: existing.join(','));
    }
  }

  Future<List<String>> getConnectedEmails(String provider) async {
    final str = await _secureStorage.read(key: 'emails_$provider');
    if (str == null || str.isEmpty) return [];
    return str.split(',');
  }

  Future<String?> getAccessToken(String provider, String email) async {
    if (_encrypter == null) await init();
    final encrypted =
        await _secureStorage.read(key: 'tokens_$provider:$email:access');
    if (encrypted == null) return null;
    return _decryptWithIV(encrypted);
  }
}
