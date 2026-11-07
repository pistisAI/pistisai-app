import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Persistence for the CF_Authorization token. Local-only; not a secret in
/// source.
abstract class AccessTokenStore {
  Future<String?> read();
  Future<void> write(String token);
  Future<void> clear();
}

class MemoryAccessTokenStore implements AccessTokenStore {
  String? _token;

  @override
  Future<void> clear() async {
    _token = null;
  }

  @override
  Future<String?> read() async => _token;

  @override
  Future<void> write(String token) async {
    _token = token;
  }
}

class SecureAccessTokenStore implements AccessTokenStore {
  SecureAccessTokenStore({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  static const _key = 'cf_access_token';
  final FlutterSecureStorage _storage;

  @override
  Future<void> clear() => _storage.delete(key: _key);

  @override
  Future<String?> read() => _storage.read(key: _key);

  @override
  Future<void> write(String token) => _storage.write(key: _key, value: token);
}
