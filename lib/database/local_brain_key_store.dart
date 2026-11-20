import 'dart:io';

import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'local_brain_encryption.dart';

/// Minimal vault used by [LocalBrainKeyStore] (OS keystore or test double).
abstract class LocalBrainKeyVault {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
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

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}

/// Resolves the AES-256 passphrase for `local_brain.sqlite`.
///
/// Key sources (in order):
/// 1. Environment variable [envVarName] (`PISTISAI_LOCAL_BRAIN_KEY`)
/// 2. OS keystore via [LocalBrainKeyVault]
///
/// Plaintext keys are never read from the repo or config files. If neither
/// source can supply a key and no encrypted database file is present, a new
/// random 32-byte key is generated and stored in the OS keystore. If an
/// encrypted (non-plaintext-header) database already exists, resolution fails
/// instead of minting a replacement key that would make the file unreadable
/// and overwrite the vault entry. If the keystore is unavailable and no env
/// key is set, resolution fails — encrypting without a persisted key would
/// lose the DB on the next launch.
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
  ///
  /// Pass [databaseFile] so a missing key cannot replace the vault entry when
  /// an encrypted database is already on disk.
  Future<String> resolveKey({File? databaseFile}) async {
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

    if (databaseFile != null &&
        await databaseFile.exists() &&
        !await isPlaintextSqliteFile(databaseFile)) {
      throw StateError(
        'An encrypted local_brain.sqlite exists at ${databaseFile.path}, but '
        'no encryption key was found in $envVarName or the OS keystore. '
        'Restoring a new key would make the database permanently unreadable '
        'and overwrite any chance to recover the original key. Set '
        '$envVarName to the original passphrase, restore the keystore entry '
        '`$secureStorageKey`, or move the database file aside before '
        'creating a fresh key.',
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
