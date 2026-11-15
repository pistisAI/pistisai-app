import 'dart:io';

import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Minimal vault used by [LocalBrainKeyStore] (OS keystore or test double).
abstract class LocalBrainKeyVault {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
}

/// [FlutterSecureStorage]-backed vault for production.
class FlutterSecureLocalBrainKeyVault implements LocalBrainKeyVault {
  FlutterSecureLocalBrainKeyVault([FlutterSecureStorage? storage])
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);
}

/// Resolves the AES-256 passphrase for `local_brain.sqlite`.
///
/// Key sources (in order):
/// 1. Environment variable [envVarName] (`PISTISAI_LOCAL_BRAIN_KEY`)
/// 2. OS keystore via [LocalBrainKeyVault]
///
/// Plaintext keys are never read from the repo or config files. If neither
/// source can supply a key, a new random 32-byte key is generated and stored
/// in the OS keystore. If the keystore is unavailable and no env key is set,
/// resolution fails — encrypting without a persisted key would lose the DB
/// on the next launch.
class LocalBrainKeyStore {
  static const String envVarName = 'PISTISAI_LOCAL_BRAIN_KEY';
  static const String secureStorageKey = 'local_brain_encryption_key';

  LocalBrainKeyStore({
    LocalBrainKeyVault? vault,
    Map<String, String>? environment,
  })  : _vault = vault ?? FlutterSecureLocalBrainKeyVault(),
        _environment = environment;

  final LocalBrainKeyVault _vault;
  final Map<String, String>? _environment;

  Map<String, String> get _env => _environment ?? Platform.environment;

  /// Returns a non-empty passphrase suitable for SQLCipher / sqlite3mc.
  Future<String> resolveKey() async {
    final fromEnv = _env[envVarName]?.trim();
    if (fromEnv != null && fromEnv.isNotEmpty) {
      return fromEnv;
    }

    try {
      final existing = await _vault.read(secureStorageKey);
      if (existing != null && existing.trim().isNotEmpty) {
        return existing.trim();
      }
    } catch (e) {
      throw StateError(
        'Cannot read $secureStorageKey from the OS keystore ($e). '
        'Set $envVarName or enable the platform keyring, then restart.',
      );
    }

    final generated = encrypt.Key.fromSecureRandom(32).base64;
    try {
      await _vault.write(secureStorageKey, generated);
    } catch (e) {
      throw StateError(
        'Cannot persist the local brain encryption key in the OS keystore ($e). '
        'Set $envVarName to a secret passphrase, or enable the platform '
        'keyring, then restart. Keys must not be written to config files.',
      );
    }
    return generated;
  }
}
