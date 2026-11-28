import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:encrypt/encrypt.dart' as encrypt;
import '../database/local_brain_key_store.dart';
import '../models/conversation.dart';
import '../utils/logger.dart';

/// Local storage service for conversations using encrypted JSON files
class LocalConversationStorage {
  static const String _fileName = 'conversations.json.enc';
  static const String _legacyFileName = 'conversations.json';
  static const String _fileKeyName = '.conversation_key';
  static const String _dirName = 'Pistisai';

  /// Short-lived support subdirectory used before the migration back to
  /// [_dirName]. Still probed so those installs do not lose history.
  static const String _interimDirName = 'chat';
  static const String _keyStorageKey = 'local_conversation_encryption_key';

  LocalConversationStorage({
    Future<Directory> Function()? documentsDirectory,
    LocalBrainKeyVault? keyVault,
  })  : _documentsDirectory = documentsDirectory,
        _keyVault = keyVault ?? FlutterSecureLocalBrainKeyVault();

  final Future<Directory> Function()? _documentsDirectory;
  final LocalBrainKeyVault _keyVault;

  encrypt.Key? _cachedKey;

  Future<Directory> _ensureDir(Directory dir) async {
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// Canonical on-disk directory for the encrypted conversation store.
  Future<Directory> _pistisaiDir() async {
    if (_documentsDirectory != null) {
      final root = await _documentsDirectory();
      return _ensureDir(Directory(p.join(root.path, _dirName)));
    }

    Directory root;
    try {
      root = await getApplicationSupportDirectory();
    } catch (_) {
      root = await getApplicationDocumentsDirectory();
    }
    return _ensureDir(Directory(p.join(root.path, _dirName)));
  }

  /// Older directories that may still hold history after path migrations.
  Future<List<Directory>> _legacyDirs() async {
    final dirs = <Directory>[];
    if (_documentsDirectory != null) {
      final root = await _documentsDirectory();
      dirs.add(Directory(p.join(root.path, _interimDirName)));
      return dirs;
    }

    try {
      final support = await getApplicationSupportDirectory();
      dirs.add(Directory(p.join(support.path, _interimDirName)));
    } catch (_) {}

    try {
      final docs = await getApplicationDocumentsDirectory();
      dirs.add(Directory(p.join(docs.path, _dirName)));
    } catch (_) {}

    return dirs;
  }

  /// Get or generate the AES key for local storage encryption.
  ///
  /// Source of truth is the OS keystore ([LocalBrainKeyVault]), matching
  /// [LocalBrainKeyStore]. A legacy plaintext `.conversation_key` file is
  /// migrated into the vault once and then deleted.
  Future<encrypt.Key> _getKey() async {
    if (_cachedKey != null) return _cachedKey!;

    try {
      final fromVault = await _keyVault.read(_keyStorageKey);
      if (fromVault != null && fromVault.trim().isNotEmpty) {
        await _deleteFileKeys();
        _cachedKey = encrypt.Key.fromBase64(fromVault.trim());
        return _cachedKey!;
      }
    } catch (e) {
      // Do not fall through to generating a key: if the keystore is only
      // temporarily unavailable, a new key written later would replace the
      // real one and the existing history could never be decrypted again.
      final fileKey = await _readFileKey();
      if (fileKey != null && fileKey.isNotEmpty) {
        _cachedKey = encrypt.Key.fromBase64(fileKey);
        return _cachedKey!;
      }
      throw StateError(
        'Cannot read the conversation encryption key from the OS keystore '
        '($e). Enable the platform keyring, then restart.',
      );
    }

    final fileKey = await _readFileKey();
    if (fileKey != null && fileKey.isNotEmpty) {
      try {
        await _keyVault.write(_keyStorageKey, fileKey);
        await _deleteFileKeys();
      } catch (e) {
        appLogger.warning(
          '[LocalChatStorage] Could not migrate file key into keystore: $e',
        );
      }
      _cachedKey = encrypt.Key.fromBase64(fileKey);
      return _cachedKey!;
    }

    // No key anywhere. Encrypted history that already exists was written
    // with a key that is gone; keep it (renamed) instead of letting the first
    // save with a new key overwrite it.
    for (final file in await _conversationDataFiles()) {
      if (file.path.endsWith(_fileName) && await file.exists()) {
        await _setAside(file, 'no encryption key found');
      }
    }

    final keyStr = encrypt.Key.fromSecureRandom(32).base64;
    try {
      await _keyVault.write(_keyStorageKey, keyStr);
    } catch (e) {
      throw StateError(
        'Cannot persist the conversation encryption key in the OS keystore ($e). '
        'Enable the platform keyring, then restart. Keys must not be written '
        'to plaintext config files.',
      );
    }

    _cachedKey = encrypt.Key.fromBase64(keyStr);
    return _cachedKey!;
  }

  Future<String?> _readFileKey() async {
    for (final file in await _fileKeyCandidates()) {
      try {
        if (!await file.exists()) continue;
        final value = (await file.readAsString()).trim();
        if (value.isEmpty) continue;
        return value;
      } catch (e) {
        appLogger.warning('[LocalChatStorage] File key read failed: $e');
      }
    }
    return null;
  }

  Future<List<File>> _fileKeyCandidates() async {
    final candidates = <File>[
      File(p.join((await _pistisaiDir()).path, _fileKeyName)),
    ];
    for (final dir in await _legacyDirs()) {
      candidates.add(File(p.join(dir.path, _fileKeyName)));
    }
    return candidates;
  }

  Future<void> _deleteFileKeys() async {
    for (final file in await _fileKeyCandidates()) {
      try {
        if (await file.exists()) {
          await file.delete();
        }
      } catch (e) {
        appLogger.warning(
          '[LocalChatStorage] Failed to delete legacy key ${file.path}: $e',
        );
      }
    }
  }

  /// Suffix of encrypted history files kept aside because the current key
  /// cannot read them. They are included in [clearAll].
  static const String unreadableSuffix = '.unreadable-';

  Future<void> _setAside(File file, String reason) async {
    final target = '${file.path}$unreadableSuffix'
        '${DateTime.now().toUtc().millisecondsSinceEpoch}';
    try {
      await file.rename(target);
      appLogger.warning(
        '[LocalChatStorage] Kept unreadable history as $target ($reason)',
      );
    } catch (e) {
      // If it cannot be moved, refuse to continue rather than overwrite it.
      throw StateError('Cannot set aside unreadable history ${file.path}: $e');
    }
  }

  /// Encrypt data: returns "base64iv:base64ciphertext"
  String _encrypt(String plaintext, encrypt.Key key) {
    final iv = encrypt.IV.fromSecureRandom(16);
    final encrypter = encrypt.Encrypter(encrypt.AES(key));
    final encrypted = encrypter.encrypt(plaintext, iv: iv);
    return '${iv.base64}:${encrypted.base64}';
  }

  /// Decrypt data stored as "base64iv:base64ciphertext"
  String _decrypt(String stored, encrypt.Key key) {
    final parts = stored.split(':');
    if (parts.length != 2) {
      throw FormatException('Invalid encrypted format');
    }
    final iv = encrypt.IV.fromBase64(parts[0]);
    final encrypter = encrypt.Encrypter(encrypt.AES(key));
    return encrypter.decrypt64(parts[1], iv: iv);
  }

  /// Get the local file for storing conversations
  Future<File> _getLocalFile() async {
    return File(p.join((await _pistisaiDir()).path, _fileName));
  }

  /// Get the legacy plaintext file path (for migration from old format)
  Future<File> _getLegacyFile() async {
    return File(p.join((await _pistisaiDir()).path, _legacyFileName));
  }

  /// Save all conversations to encrypted local storage
  Future<void> saveConversations(List<Conversation> conversations) async {
    try {
      final key = await _getKey();
      final file = await _getLocalFile();
      final jsonData = conversations.map((c) => c.toJson()).toList();
      final plaintext = jsonEncode(jsonData);
      final encrypted = _encrypt(plaintext, key);
      await file.writeAsString(encrypted);
      appLogger.info(
        '[LocalChatStorage] Saved ${conversations.length} conversations to ${file.path}',
      );
    } catch (e) {
      appLogger.error(
        '[LocalChatStorage] Error saving conversations: $e',
        error: e,
      );
      // Callers must know: a migration must not delete its source, and the
      // chat screen warns that history is not being saved.
      rethrow;
    }
  }

  /// Load all conversations from encrypted local storage,
  /// with automatic migration from older paths / plaintext format.
  Future<List<Conversation>> loadConversations() async {
    try {
      final key = await _getKey();
      final file = await _getLocalFile();
      if (await file.exists()) {
        final content = await file.readAsString();
        if (content.isEmpty) return [];
        final String plaintext;
        try {
          plaintext = _decrypt(content, key);
        } catch (e) {
          // Wrong key or damaged file. Keep it, so the next save cannot
          // overwrite history that may still be recoverable.
          await _setAside(file, 'cannot be decrypted: $e');
          return [];
        }
        final List<dynamic> jsonData = jsonDecode(plaintext);
        return jsonData.map((data) => Conversation.fromJson(data)).toList();
      }

      final migrated = await _migrateFromOlderLocations(key);
      if (migrated != null) {
        return migrated;
      }

      return await _migrateFromLegacy(key);
    } catch (e) {
      appLogger.error(
        '[LocalChatStorage] Error loading conversations: $e',
        error: e,
      );
      return [];
    }
  }

  Future<List<Conversation>?> _migrateFromOlderLocations(
      encrypt.Key key) async {
    for (final dir in await _legacyDirs()) {
      final enc = File(p.join(dir.path, _fileName));
      if (await enc.exists()) {
        try {
          final content = await enc.readAsString();
          if (content.isEmpty) continue;
          final plaintext = _decrypt(content, key);
          final List<dynamic> jsonData = jsonDecode(plaintext);
          final conversations =
              jsonData.map((data) => Conversation.fromJson(data)).toList();
          await saveConversations(conversations);
          appLogger.info(
            '[LocalChatStorage] Migrated encrypted history from ${enc.path}',
          );
          return conversations;
        } catch (e) {
          appLogger.warning(
            '[LocalChatStorage] Could not migrate ${enc.path}: $e',
          );
        }
      }

      final plaintextLegacy = File(p.join(dir.path, _legacyFileName));
      if (await plaintextLegacy.exists()) {
        final conversations = await _migratePlaintextFile(plaintextLegacy);
        if (conversations.isNotEmpty) {
          return conversations;
        }
      }
    }
    return null;
  }

  /// Migrate from legacy plaintext conversations.json to encrypted format.
  Future<List<Conversation>> _migrateFromLegacy(encrypt.Key key) async {
    try {
      final legacyFile = await _getLegacyFile();
      if (!await legacyFile.exists()) return [];
      return await _migratePlaintextFile(legacyFile);
    } catch (e) {
      appLogger.error('[LocalChatStorage] Migration from legacy failed',
          error: e);
      return [];
    }
  }

  Future<List<Conversation>> _migratePlaintextFile(File legacyFile) async {
    appLogger.info(
      '[LocalChatStorage] Migrating legacy conversations.json → encrypted format',
    );
    final content = await legacyFile.readAsString();
    if (content.isEmpty) return [];

    final List<dynamic> jsonData = jsonDecode(content);
    final conversations =
        jsonData.map((data) => Conversation.fromJson(data)).toList();

    await saveConversations(conversations);

    try {
      await legacyFile.delete();
    } catch (_) {}
    appLogger
        .info('[LocalChatStorage] Migration complete, legacy file deleted');
    return conversations;
  }

  /// Every conversation data file path that must be gone after a wipe:
  /// encrypted + plaintext under the canonical dir and all legacy dirs.
  Future<List<File>> _conversationDataFiles() async {
    final dirs = <Directory>[
      await _pistisaiDir(),
      ...await _legacyDirs(),
    ];
    final files = <File>[];
    final seen = <String>{};
    for (final dir in dirs) {
      for (final name in [
        _fileName,
        _legacyFileName,
        '$_fileName.retired',
        '$_legacyFileName.retired',
      ]) {
        final file = File(p.join(dir.path, name));
        if (seen.add(file.path)) {
          files.add(file);
        }
      }
      try {
        if (await dir.exists()) {
          await for (final entity in dir.list()) {
            if (entity is File &&
                p
                    .basename(entity.path)
                    .startsWith('$_fileName$unreadableSuffix') &&
                seen.add(entity.path)) {
              files.add(entity);
            }
          }
        }
      } catch (_) {}
    }
    return files;
  }

  /// Renames live conversation files so they are no longer the store.
  ///
  /// Called once the Drift database has imported them (#1065). Unreadable
  /// archives are left in place so a later launch can still recover them.
  /// Missing files are skipped. Returns the paths the files were renamed to.
  Future<List<String>> retire() async {
    final renamed = <String>[];
    for (final file in await _conversationDataFiles()) {
      if (!await file.exists()) continue;
      if (p.basename(file.path).contains(unreadableSuffix)) continue;
      if (file.path.endsWith('.retired')) continue;
      final target = File('${file.path}.retired');
      if (await target.exists()) {
        await target.delete();
      }
      await file.rename(target.path);
      renamed.add(target.path);
    }
    return renamed;
  }

  /// True when a conversation file was set aside because it could not be read.
  Future<bool> hasUnreadableArchive() async {
    for (final file in await _conversationDataFiles()) {
      if (p.basename(file.path).contains(unreadableSuffix) &&
          await file.exists()) {
        return true;
      }
    }
    return false;
  }

  /// Paths of conversation data files that still exist on disk.
  Future<List<String>> listExistingConversationDataPaths() async {
    final remaining = <String>[];
    for (final file in await _conversationDataFiles()) {
      if (await file.exists()) {
        remaining.add(file.path);
      }
    }
    return remaining;
  }

  /// Clear all local conversations from the canonical and legacy locations.
  ///
  /// Deletes both encrypted and plaintext conversation files. Rethrows on
  /// failure so a wipe cannot report success when files remain.
  Future<void> clearAll() async {
    Object? firstError;
    StackTrace? firstStack;
    for (final file in await _conversationDataFiles()) {
      try {
        if (await file.exists()) {
          await file.delete();
        }
      } catch (e, stack) {
        appLogger.error(
          '[LocalChatStorage] Error clearing ${file.path}',
          error: e,
        );
        firstError ??= e;
        firstStack ??= stack;
      }
    }
    try {
      await _deleteFileKeys();
      await _keyVault.delete(_keyStorageKey);
    } catch (e, stack) {
      appLogger.error(
        '[LocalChatStorage] Error clearing conversation encryption key',
        error: e,
      );
      firstError ??= e;
      firstStack ??= stack;
    }
    _cachedKey = null;
    if (firstError != null) {
      Error.throwWithStackTrace(firstError, firstStack ?? StackTrace.current);
    }
  }
}
