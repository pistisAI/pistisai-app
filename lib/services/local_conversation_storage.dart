import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
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
  static final FlutterSecureStorage _secureStorage =
      const FlutterSecureStorage();

  LocalConversationStorage({
    Future<Directory> Function()? documentsDirectory,
    bool skipKeyring = false,
  })  : _documentsDirectory = documentsDirectory,
        _skipKeyring = skipKeyring;

  final Future<Directory> Function()? _documentsDirectory;
  final bool _skipKeyring;

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
  /// The file-backed key is the source of truth so the main channel survives
  /// restarts when libsecret/keyring is unavailable. Keyring is a best-effort
  /// cache only and must never block save/load.
  Future<encrypt.Key> _getKey() async {
    if (_cachedKey != null) return _cachedKey!;

    String? keyStr = await _readFileKey();

    if ((keyStr == null || keyStr.isEmpty) && !_skipKeyring) {
      try {
        keyStr = await _secureStorage.read(key: _keyStorageKey);
        if (keyStr != null && keyStr.isNotEmpty) {
          await _writeFileKey(keyStr);
        }
      } catch (e) {
        appLogger.warning(
          '[LocalChatStorage] Keyring read failed, using file-backed key: $e',
        );
      }
    }

    if (keyStr == null || keyStr.isEmpty) {
      keyStr = encrypt.Key.fromSecureRandom(32).base64;
      await _writeFileKey(keyStr);
      if (!_skipKeyring) {
        try {
          await _secureStorage.write(key: _keyStorageKey, value: keyStr);
        } catch (e) {
          appLogger.warning(
            '[LocalChatStorage] Keyring write skipped: $e',
          );
        }
      }
    }

    _cachedKey = encrypt.Key.fromBase64(keyStr);
    return _cachedKey!;
  }

  Future<String?> _readFileKey() async {
    final candidates = <File>[
      File(p.join((await _pistisaiDir()).path, _fileKeyName)),
    ];
    for (final dir in await _legacyDirs()) {
      candidates.add(File(p.join(dir.path, _fileKeyName)));
    }

    for (final file in candidates) {
      try {
        if (!await file.exists()) continue;
        final value = (await file.readAsString()).trim();
        if (value.isEmpty) continue;
        final primary = File(p.join((await _pistisaiDir()).path, _fileKeyName));
        if (file.path != primary.path) {
          await _writeFileKey(value);
        }
        return value;
      } catch (e) {
        appLogger.warning('[LocalChatStorage] File key read failed: $e');
      }
    }
    return null;
  }

  Future<void> _writeFileKey(String keyStr) async {
    final file = File(p.join((await _pistisaiDir()).path, _fileKeyName));
    await file.writeAsString(keyStr, flush: true);
    if (!Platform.isWindows) {
      try {
        await Process.run('chmod', ['600', file.path]);
      } catch (e) {
        appLogger.warning('[LocalChatStorage] chmod 600 failed: $e');
      }
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
        final plaintext = _decrypt(content, key);
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
      return _migratePlaintextFile(legacyFile);
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

  /// Clear all local conversations
  Future<void> clearAll() async {
    try {
      final file = await _getLocalFile();
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      appLogger.error(
        '[LocalChatStorage] Error clearing storage',
        error: e,
      );
    }
  }
}
