import 'dart:convert';
import 'dart:io';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:pistisai/database/drift_local_brain.dart';
import 'package:uuid/uuid.dart';

/// Memory Service
/// Manages avatar long-term memory with vector embeddings for semantic search
class MemoryService {
  final LocalBrain database;
  final Uuid _uuid = const Uuid();
  final String _embeddingEndpoint;

  bool _isInitialized = false;
  String? _lastError;

  bool get isInitialized => _isInitialized;
  String? get lastError => _lastError;

  MemoryService({
    required this.database,
    String? embeddingEndpoint,
  }) : _embeddingEndpoint = embeddingEndpoint ?? 'http://localhost:1234/v1/embeddings';

  /// Generate embedding vector for text using LM Studio embedding endpoint.
  Future<List<double>> _generateEmbedding(String text) async {
    try {
      final client = HttpClient();
      final request = await client.postUrl(Uri.parse(_embeddingEndpoint));
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode({
        'input': text,
        'model': 'gemma-4-e4b',
      }));

      final response = await request.close();
      if (response.statusCode != 200) {
        debugPrint('[MemoryService] Embedding API returned ${response.statusCode}');
        return [];
      }

      final body = await response.transform(utf8.decoder).join();
      final data = jsonDecode(body) as Map<String, dynamic>;
      final embedding = (data['data'] as List).first['embedding'] as List<double>;
      return embedding;
    } catch (e) {
      debugPrint('[MemoryService] Embedding generation failed: $e');
      return [];
    }
  }

  /// Initialize the memory service
  Future<void> initialize() async {
    if (_isInitialized) {
      debugPrint('[MemoryService] Already initialized, skipping');
      return;
    }

    debugPrint('[MemoryService] Initializing...');
    _isInitialized = true;
    _lastError = null;
    debugPrint('[MemoryService] Initialized successfully');
  }

  /// Store a memory with embedding
  Future<String> storeMemory({
    required String conversationId,
    required String content,
    String? summary,
    List<double>? embedding,
  }) async {
    if (!_isInitialized) {
      final error = 'Service not initialized';
      _lastError = error;
      debugPrint('[MemoryService] $error');
      throw StateError(error);
    }

    final id = _uuid.v4();
    debugPrint('[MemoryService] Storing memory: $id');

    try {
      // Generate embedding if not provided
      final List<double> finalEmbedding;
      if (embedding != null) {
        finalEmbedding = embedding;
      } else {
        finalEmbedding = await _generateEmbedding(content);
      }

      final embeddingJson = jsonEncode(finalEmbedding);

      await database.insertMemory(
        ConversationMemoriesCompanion.insert(
          id: id,
          conversationId: conversationId,
          content: content,
          embedding: embeddingJson,
          summary: Value(summary),
        ),
      );

      _lastError = null;
      debugPrint('[MemoryService] Memory stored: $id');
      return id;
    } catch (e) {
      _lastError = 'Failed to store memory: $e';
      debugPrint('[MemoryService] $_lastError');
      rethrow;
    }
  }

  /// Search memories by content (semantic search)
  Future<List<ConversationMemory>> searchMemories(String query) async {
    if (!_isInitialized) {
      final error = 'Service not initialized';
      _lastError = error;
      debugPrint('[MemoryService] $error');
      throw StateError(error);
    }

    debugPrint('[MemoryService] Searching memories for: $query');
    try {
      final results = await database.searchMemoriesByContent(query);
      _lastError = null;
      debugPrint('[MemoryService] Found ${results.length} memories');
      return results;
    } catch (e) {
      _lastError = 'Failed to search memories: $e';
      debugPrint('[MemoryService] $_lastError');
      return [];
    }
  }

  /// Get all memories for a specific conversation
  Future<List<ConversationMemory>> getMemoriesForConversation(
      String conversationId) async {
    if (!_isInitialized) {
      final error = 'Service not initialized';
      _lastError = error;
      debugPrint('[MemoryService] $error');
      throw StateError(error);
    }

    debugPrint('[MemoryService] Getting memories for: $conversationId');
    try {
      final memories =
          await database.getMemoriesForConversation(conversationId);
      _lastError = null;
      debugPrint('[MemoryService] Found ${memories.length} memories');
      return memories;
    } catch (e) {
      _lastError = 'Failed to get memories: $e';
      debugPrint('[MemoryService] $_lastError');
      return [];
    }
  }

  /// Get recent memories across all conversations
  Future<List<ConversationMemory>> getRecentMemories({int limit = 50}) async {
    if (!_isInitialized) {
      final error = 'Service not initialized';
      _lastError = error;
      debugPrint('[MemoryService] $error');
      throw StateError(error);
    }

    debugPrint('[MemoryService] Getting recent memories (limit: $limit)');
    try {
      final memories = await database.getRecentMemories(limit: limit);
      _lastError = null;
      debugPrint('[MemoryService] Found ${memories.length} recent memories');
      return memories;
    } catch (e) {
      _lastError = 'Failed to get recent memories: $e';
      debugPrint('[MemoryService] $_lastError');
      return [];
    }
  }

  /// Delete all memories for a conversation
  Future<int> deleteMemoriesForConversation(String conversationId) async {
    if (!_isInitialized) {
      final error = 'Service not initialized';
      _lastError = error;
      debugPrint('[MemoryService] $error');
      throw StateError(error);
    }

    debugPrint('[MemoryService] Deleting memories for: $conversationId');
    try {
      final count =
          await database.deleteMemoriesForConversation(conversationId);
      _lastError = null;
      debugPrint('[MemoryService] Deleted $count memories');
      return count;
    } catch (e) {
      _lastError = 'Failed to delete memories: $e';
      debugPrint('[MemoryService] $_lastError');
      return 0;
    }
  }

  /// Dispose of the memory service
  Future<void> dispose() async {
    if (!_isInitialized) {
      return;
    }

    debugPrint('[MemoryService] Disposing...');
    _isInitialized = false;
    _lastError = null;
    debugPrint('[MemoryService] Disposed successfully');
  }
}
