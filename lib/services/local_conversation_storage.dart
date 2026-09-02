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

  Future<Directory> _pistisaiDir() async {
    final root = _documentsDirectory != null
        ? await _documentsDirectory()
        : await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(root.path, 'Pistisai'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// Get or generate the AES key for local storage encryption.
  ///
  /// Prefers the OS keychain. When libsecret/keyring is unavailable (common
  /// on headless desktops), persist the key next to the conversation file so
  /// the main channel survives app restarts.
  Future<encrypt.Key> _getKey() async {
    if (_cachedKey != null) return _cachedKey!;

    String? keyStr;
    if (!_skipKeyring) {
      try {
        keyStr = await _secureStorage.read(key: _keyStorageKey);
      } catch (e) {
        appLogger.warning(
          '[LocalChatStorage] Keyring read failed, using file-backed key: $e',
        );
      }
    }

    if (keyStr == null || keyStr.isEmpty) {
      keyStr = await _readFileKey();
    }

    if (keyStr == null || keyStr.isEmpty) {
      final key = encrypt.Key.fromSecureRandom(32);
      keyStr = key.base64;
      var storedInKeyring = false;
      if (!_skipKeyring) {
        try {
          await _secureStorage.write(key: _keyStorageKey, value: keyStr);
          storedInKeyring = true;
        } catch (e) {
          appLogger.warning(
            '[LocalChatStorage] Keyring write failed, persisting key to disk: $e',
          );
        }
      }
      if (!storedInKeyring) {
        await _writeFileKey(keyStr);
      }
    }

    _cachedKey = encrypt.Key.fromBase64(keyStr);
    return _cachedKey!;
  }

  Future<String?> _readFileKey() async {
    try {
      final file = File(p.join((await _pistisaiDir()).path, _fileKeyName));
      if (!await file.exists()) return null;
      final value = (await file.readAsString()).trim();
      return value.isEmpty ? null : value;
    } catch (e) {
      appLogger.warning('[LocalChatStorage] File key read failed: $e');
      return null;
    }
  }

  Future<void> _writeFileKey(String keyStr) async {
    final file = File(p.join((await _pistisaiDir()).path, _fileKeyName));
    await file.writeAsString(keyStr);
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
      appLogger.debug(
        '[LocalChatStorage] Saved ${conversations.length} conversations to ${file.path}',
      );
    } catch (e) {
      appLogger.error(
        '[LocalChatStorage] Error saving conversations',
        error: e,
      );
    }
  }

  /// Load all conversations from encrypted local storage,
  /// with automatic migration from legacy plaintext format.
  Future<List<Conversation>> loadConversations() async {
    try {
      final key = await _getKey();
      final file = await _getLocalFile();
      if (!await file.exists()) {
        // Check for legacy plaintext file and migrate
        return await _migrateFromLegacy(key);
      }

      final content = await file.readAsString();
      if (content.isEmpty) return [];

      final plaintext = _decrypt(content, key);
      final List<dynamic> jsonData = jsonDecode(plaintext);
      return jsonData.map((data) => Conversation.fromJson(data)).toList();
    } catch (e) {
      appLogger.error(
        '[LocalChatStorage] Error loading conversations',
        error: e,
      );
      return [];
    }
  }

  /// Migrate from legacy plaintext conversations.json to encrypted format.
  /// Reads the old file, saves it encrypted, then deletes the legacy file.
  Future<List<Conversation>> _migrateFromLegacy(encrypt.Key key) async {
    try {
      final legacyFile = await _getLegacyFile();
      if (!await legacyFile.exists()) return [];

      appLogger.info('[LocalChatStorage] Migrating legacy conversations.json → encrypted format');
      final content = await legacyFile.readAsString();
      if (content.isEmpty) return [];

      final List<dynamic> jsonData = jsonDecode(content);
      final conversations =
          jsonData.map((data) => Conversation.fromJson(data)).toList();

      // Save in new encrypted format
      await saveConversations(conversations);

      // Delete legacy file
      await legacyFile.delete();
      appLogger.info('[LocalChatStorage] Migration complete, legacy file deleted');
      return conversations;
    } catch (e) {
      appLogger.error('[LocalChatStorage] Migration from legacy failed', error: e);
      return [];
    }
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
