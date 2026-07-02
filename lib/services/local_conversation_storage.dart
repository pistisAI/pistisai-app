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
  static const String _keyStorageKey = 'local_conversation_encryption_key';
  static final FlutterSecureStorage _secureStorage =
      const FlutterSecureStorage();

  encrypt.Key? _cachedKey;

  /// Get or generate the AES key for local storage encryption.
  /// The key is stored in the OS keychain via flutter_secure_storage.
  Future<encrypt.Key> _getKey() async {
    if (_cachedKey != null) return _cachedKey!;

    String? keyStr = await _secureStorage.read(key: _keyStorageKey);
    if (keyStr == null) {
      final key = encrypt.Key.fromSecureRandom(32);
      keyStr = key.base64;
      await _secureStorage.write(key: _keyStorageKey, value: keyStr);
    }

    _cachedKey = encrypt.Key.fromBase64(keyStr);
    return _cachedKey!;
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
    final directory = await getApplicationDocumentsDirectory();
    final path = p.join(directory.path, 'Pistisai', _fileName);
    final file = File(path);

    // Ensure directory exists
    if (!await file.parent.exists()) {
      await file.parent.create(recursive: true);
    }

    return file;
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

  /// Load all conversations from encrypted local storage
  Future<List<Conversation>> loadConversations() async {
    try {
      final key = await _getKey();
      final file = await _getLocalFile();
      if (!await file.exists()) {
        return [];
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
