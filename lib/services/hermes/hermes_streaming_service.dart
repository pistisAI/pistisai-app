import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../brand/brand.dart';
import '../../models/agent_event.dart';
import '../../models/conversation.dart';
import '../../models/message.dart';
import '../../models/streaming_message.dart';
import '../streaming_service.dart';
import 'hermes_session_transcript.dart';
import '../../utils/logger.dart';

/// Streaming service for the first-class Hermes **pistisai** messaging platform.
///
/// Connects to the local Hermes gateway HTTP surface
/// (default: http://127.0.0.1:8642) used by [StreamingChatService].
///
/// Chat goes through the pistisai platform only:
/// - POST `/api/pistisai/messages` — inbound user turn (`platform: pistisai`)
/// - GET  `/api/sessions/{id}/messages` — shared transcript / reply poll
/// - GET  `/v1/models`, `/health` — discovery and readiness
///
/// There is no generic `api_server` / `/v1/runs` chat path.
class HermesStreamingService extends StreamingService {
  String _baseUrl;
  final String? _apiKey;

  /// HTTP client — kept alive for connection pooling.
  http.Client? _client;

  /// Cached connection state.
  StreamingConnection _connection = StreamingConnection.disconnected();

  /// Model IDs fetched from Hermes /v1/models endpoint.
  List<String> _modelIds = [];

  /// Stream controller for message bus (required by abstract interface).
  final StreamController<StreamingMessage> _messageController =
      StreamController<StreamingMessage>.broadcast();

  /// Stream controller for agent events (tool calls, lifecycle).
  /// Consumers who want full agent awareness listen here.
  final StreamController<AgentEvent> _agentEventController =
      StreamController<AgentEvent>.broadcast();

  /// Hermes session ids keyed by the app conversation id (`pistisai`).
  final Map<String, String> _runtimeSessionsByConversation = {};

  /// Hermes session currently bound to [conversationId], if any.
  String? runtimeSessionIdFor(String conversationId) =>
      _runtimeSessionsByConversation[conversationId];

  void _bindRuntimeSession(String conversationId, String? sessionId) {
    final trimmed = sessionId?.trim();
    if (trimmed == null || trimmed.isEmpty) return;
    _runtimeSessionsByConversation[conversationId] = trimmed;
  }

  String _sessionForConversation(String conversationId) =>
      _runtimeSessionsByConversation[conversationId] ?? conversationId;

  HermesStreamingService({
    String? baseUrl,
    String? apiKey,
    http.Client? client,
  })  : _baseUrl = baseUrl ?? 'http://127.0.0.1:8642',
        _apiKey = apiKey,
        _client = client;

  String get baseUrl => _baseUrl;

  /// Point this client at a newly discovered desktop hub (mobile Tailscale).
  void updateBaseUrl(String url) {
    final trimmed = url.trim();
    if (trimmed.isEmpty) {
      return;
    }
    _baseUrl = trimmed.endsWith('/')
        ? trimmed.substring(0, trimmed.length - 1)
        : trimmed;
  }

  /// Stream of structured agent events for consumers who want full
  /// agent awareness (tool calls, reasoning, lifecycle).
  ///
  /// This is in addition to the standard [messageStream] which carries
  /// text/reasoning chunks in the traditional StreamingMessage format.
  Stream<AgentEvent> get agentEventStream => _agentEventController.stream;

  // ---------------------------------------------------------------------------
  // StreamingService interface
  // ---------------------------------------------------------------------------

  @override
  Stream<StreamingMessage> get messageStream => _messageController.stream;

  @override
  StreamingConnection get connection => _connection;

  @override
  Future<void> establishConnection() async {
    _client ??= http.Client();
    try {
      final response = await _client!
          .get(
            Uri.parse('$_baseUrl/health'),
            headers: _headers(),
          )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        _connection = StreamingConnection.connected(_baseUrl);
        debugPrint('[Hermes] Connected to $_baseUrl');
        await _fetchModels();
        notifyListeners();
      } else {
        _connection = StreamingConnection.error(
          'Health check returned ${response.statusCode}',
          endpoint: _baseUrl,
        );
        notifyListeners();
      }
    } on SocketException {
      _connection = StreamingConnection.error(
        'Cannot reach Hermes at $_baseUrl',
        endpoint: _baseUrl,
      );
      notifyListeners();
    } on TimeoutException {
      _connection = StreamingConnection.error(
        'Connection to $_baseUrl timed out',
        endpoint: _baseUrl,
      );
      notifyListeners();
    } catch (e) {
      _connection = StreamingConnection.error(
        'Connection failed: $e',
        endpoint: _baseUrl,
      );
      notifyListeners();
    }
  }

  @override
  Future<void> closeConnection() async {
    _connection = StreamingConnection.disconnected();
    _client?.close();
    _client = null;
    notifyListeners();
  }

  @override
  Future<bool> testConnection() async {
    try {
      await establishConnection();
      return _connection.isActive;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<List<String>> getAvailableModels() async {
    await _fetchModels();
    return _modelIds;
  }

  @override
  Stream<StreamingMessage> streamResponse({
    required String prompt,
    required String model,
    required String conversationId,
    List<Map<String, String>>? history,
  }) async* {
    if (!_connection.isActive) {
      await establishConnection();
    }

    if (!_connection.isActive) {
      final errorMsg = StreamingMessage.error(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        conversationId: conversationId,
        error: 'Not connected to Hermes',
        sequence: 0,
      );
      _messageController.add(errorMsg);
      yield errorMsg;
      return;
    }

    yield* _streamViaPistisaiChannel(
      prompt: prompt,
      model: model,
      conversationId: conversationId,
    );
  }

  // ---------------------------------------------------------------------------
  // First-class pistisai platform channel
  // ---------------------------------------------------------------------------

  /// Post to `/api/pistisai/messages` then poll the shared session transcript
  /// for the assistant reply. No generic api_server / `/v1/runs` path.
  Stream<StreamingMessage> _streamViaPistisaiChannel({
    required String prompt,
    required String model,
    required String conversationId,
  }) async* {
    final client = _client ?? http.Client();
    final messageId = DateTime.now().millisecondsSinceEpoch.toString();
    var sequence = 0;
    // The UI chat id (`pistisai`) is the platform chat_id; Hermes derives the
    // session key `agent:main:pistisai:dm:<chat_id>` itself. Never post a
    // resolved Hermes session id here — that would open a new chat/session.
    final chatId = conversationId;

    _connection = StreamingConnection.streaming(_baseUrl);
    notifyListeners();

    // Snapshot assistant message ids already in the transcript so we can
    // detect the new reply after inbound dispatch.
    final beforeIds = <String>{};
    try {
      final existing = await fetchSessionMessages(conversationId);
      if (existing != null) {
        for (final message in existing) {
          if (message.role == MessageRole.assistant) {
            beforeIds.add(message.id);
          }
        }
      }
    } catch (e) {
      appLogger.warning('[Hermes] pre-send transcript snapshot failed: $e');
    }

    try {
      final response = await client
          .post(
            Uri.parse('$_baseUrl/api/pistisai/messages'),
            headers: {
              ..._headers(),
              'Accept': 'application/json',
            },
            body: jsonEncode({
              'message': prompt,
              'conversation_id': chatId,
              'user_id': 'operator',
              'user_name': 'Christopher',
              'message_id': messageId,
            }),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        final errorBody = response.body;
        appLogger.error(
          '[Hermes] pistisai messages error ${response.statusCode}: $errorBody',
        );
        final errorMsg = StreamingMessage.error(
          id: messageId,
          conversationId: conversationId,
          error:
              '${Brand.current.productName} channel failed (${response.statusCode}): $errorBody',
          sequence: sequence++,
        );
        _messageController.add(errorMsg);
        yield errorMsg;
        return;
      }

      appLogger.info(
        '[Hermes] Posted to pistisai channel chat_id=$chatId '
        '(session key agent:main:pistisai:dm:$chatId)',
      );
    } on TimeoutException {
      final errorMsg = StreamingMessage.error(
        id: messageId,
        conversationId: conversationId,
        error: '${Brand.current.productName} channel timed out posting message',
        sequence: sequence++,
      );
      _messageController.add(errorMsg);
      yield errorMsg;
      return;
    } catch (e) {
      final errorMsg = StreamingMessage.error(
        id: messageId,
        conversationId: conversationId,
        error: '${Brand.current.productName} channel post failed: $e',
        sequence: sequence++,
      );
      _messageController.add(errorMsg);
      yield errorMsg;
      return;
    }

    // Poll the harness transcript for the new assistant reply.
    const pollInterval = Duration(milliseconds: 750);
    const maxWait = Duration(minutes: 10);
    final deadline = DateTime.now().add(maxWait);
    var lastEmitted = '';
    var sawReply = false;

    while (DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(pollInterval);
      final harness = await fetchSessionMessages(conversationId);
      if (harness == null) continue;

      Message? newest;
      for (final message in harness.reversed) {
        if (message.role != MessageRole.assistant) continue;
        if (beforeIds.contains(message.id)) continue;
        newest = message;
        break;
      }
      if (newest == null) continue;

      sawReply = true;
      final content = newest.content;
      if (content != lastEmitted) {
        final extended = content.startsWith(lastEmitted);
        final replaces = !extended && lastEmitted.isNotEmpty;
        final delta =
            extended ? content.substring(lastEmitted.length) : content;
        lastEmitted = content;
        if (delta.isNotEmpty) {
          final chunk = StreamingMessage.chunk(
            id: messageId,
            conversationId: conversationId,
            chunk: replaces ? content : delta,
            replacesContent: replaces,
            sequence: sequence++,
            model: model == 'default' ? 'hermes-agent' : model,
          );
          _messageController.add(chunk);
          yield chunk;
        }
      }

      // Heuristic: once we have assistant text and the last harness row is
      // that assistant (not a newer user turn), treat the turn as complete.
      if (content.trim().isNotEmpty && harness.last.id == newest.id) {
        // Give the agent a short settle window for late tool/final text.
        await Future<void>.delayed(const Duration(milliseconds: 1200));
        final settled = await fetchSessionMessages(conversationId);
        if (settled == null) break;
        Message? settledNewest;
        for (final message in settled.reversed) {
          if (message.role != MessageRole.assistant) continue;
          if (beforeIds.contains(message.id)) continue;
          settledNewest = message;
          break;
        }
        if (settledNewest != null &&
            settledNewest.content == lastEmitted &&
            settled.last.id == settledNewest.id) {
          break;
        }
        if (settledNewest != null && settledNewest.content != lastEmitted) {
          final content2 = settledNewest.content;
          final extended = content2.startsWith(lastEmitted);
          final replaces = !extended && lastEmitted.isNotEmpty;
          final delta =
              extended ? content2.substring(lastEmitted.length) : content2;
          lastEmitted = content2;
          if (delta.isNotEmpty) {
            final chunk = StreamingMessage.chunk(
              id: messageId,
              conversationId: conversationId,
              chunk: replaces ? content2 : delta,
              replacesContent: replaces,
              sequence: sequence++,
              model: model == 'default' ? 'hermes-agent' : model,
            );
            _messageController.add(chunk);
            yield chunk;
          }
        }
        break;
      }
    }

    if (!sawReply) {
      final errorMsg = StreamingMessage.error(
        id: messageId,
        conversationId: conversationId,
        error:
            '${Brand.current.productName} channel produced no assistant reply',
        sequence: sequence++,
      );
      _messageController.add(errorMsg);
      yield errorMsg;
      return;
    }

    final complete = StreamingMessage.complete(
      id: messageId,
      conversationId: conversationId,
      sequence: sequence++,
      model: model == 'default' ? 'hermes-agent' : model,
    );
    _messageController.add(complete);
    yield complete;
    _connection = StreamingConnection.connected(_baseUrl);
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Non-streaming completion (pistisai channel)
  // ---------------------------------------------------------------------------

  /// Send a prompt on the pistisai channel and return the assistant reply text.
  Future<String?> complete({
    required String prompt,
    String model = 'hermes-agent',
    String conversationId = Conversation.pistisaiChannelId,
    List<Map<String, String>>? history,
  }) async {
    if (!_connection.isActive) {
      await establishConnection();
    }
    if (!_connection.isActive) return null;

    final buffer = StringBuffer();
    await for (final message in _streamViaPistisaiChannel(
      prompt: prompt,
      model: model,
      conversationId: conversationId,
    )) {
      if (message.hasError) return null;
      if (message.chunk.isNotEmpty) buffer.write(message.chunk);
    }
    final text = buffer.toString().trim();
    return text.isEmpty ? null : text;
  }

  /// Load the shared harness transcript for [sessionId].
  ///
  /// Every Pistisai device uses the same UI channel id (`pistisai`).
  /// Returns an empty list when the session does not exist yet, and null when
  /// the harness cannot be read.
  Future<List<Message>?> fetchSessionMessages(String sessionId) async {
    try {
      final client = _client ?? http.Client();
      final runtimeId = _sessionForConversation(sessionId);

      Future<http.Response> getMessages(String id) {
        return client.get(
          Uri.parse(
            '$_baseUrl/api/sessions/${Uri.encodeComponent(id)}/messages'
            '?order=oldest&limit=500',
          ),
          headers: {
            ..._headers(),
            'Accept': 'application/json',
          },
        ).timeout(const Duration(seconds: 8));
      }

      // The pistisai DM key (`agent:main:pistisai:dm:<chat_id>`) is not
      // addressable on /api/sessions/{id}; Hermes stores it under a generated
      // session id (e.g. `20261104_190859_119a1e2b`, source=pistisai). Resolve
      // it each poll so resets/new sessions are followed.
      var targetId = runtimeId;
      if (sessionId == Conversation.pistisaiChannelId) {
        targetId = await _resolvePistisaiSessionId() ?? runtimeId;
      }
      var response = await getMessages(targetId);
      if (response.statusCode == 404 && targetId != sessionId) {
        response = await getMessages(sessionId);
      }
      if (response.statusCode == 404) {
        // No session yet (first message not processed). Never invent one via
        // POST /api/sessions — that creates junk rows / 409 loops.
        _logPollTarget(sessionId, targetId, 404);
        return const [];
      }
      _logPollTarget(sessionId, targetId, response.statusCode);
      if (response.statusCode != 200) return null;

      final decoded = jsonDecode(response.body);
      if (decoded is Map && decoded['session_id'] is String) {
        _bindRuntimeSession(sessionId, decoded['session_id'] as String);
      }
      return messagesFromHermesSessionBody(response.body);
    } catch (e) {
      appLogger.error('[Hermes] Failed to load shared session', error: e);
      return null;
    }
  }

  final Map<String, String> _lastPollLog = {};

  void _logPollTarget(String chatId, String targetId, int status) {
    final key = '$targetId:$status';
    if (_lastPollLog[chatId] == key) return;
    _lastPollLog[chatId] = key;
    debugPrint('[Hermes] transcript poll chat=$chatId -> session=$targetId '
        'HTTP $status');
  }

  /// Resolve the Hermes session id currently backing the pistisai DM
  /// (session key `agent:main:pistisai:dm:pistisai`): the most recently
  /// active `source=pistisai` session.
  Future<String?> _resolvePistisaiSessionId() async {
    try {
      final client = _client ?? http.Client();
      final response = await client.get(
        Uri.parse('$_baseUrl/api/sessions?source=pistisai&limit=20'),
        headers: {..._headers(), 'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) return null;
      final decoded = jsonDecode(response.body);
      final data = decoded is Map ? decoded['data'] : null;
      if (data is! List) return null;
      String? bestId;
      var bestActive = double.negativeInfinity;
      for (final row in data) {
        if (row is! Map) continue;
        if (row['source'] != null && row['source'] != 'pistisai') continue;
        if (row['archived'] == true || row['is_internal_child'] == true) {
          continue;
        }
        final id = row['id'];
        if (id is! String || id.isEmpty) continue;
        final active = row['last_active'] ?? row['started_at'];
        final ts =
            active is num ? active.toDouble() : double.tryParse('$active') ?? 0;
        if (ts > bestActive) {
          bestActive = ts;
          bestId = id;
        }
      }
      return bestId;
    } catch (e) {
      appLogger.warning('[Hermes] pistisai session resolve failed: $e');
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // Internal helpers
  // ---------------------------------------------------------------------------

  Map<String, String> _headers() {
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'text/event-stream',
    };
    if (_apiKey != null && _apiKey.isNotEmpty) {
      headers['Authorization'] = 'Bearer $_apiKey';
    }
    return headers;
  }

  Future<void> _fetchModels() async {
    try {
      final client = _client ?? http.Client();
      final response = await client
          .get(
            Uri.parse('$_baseUrl/v1/models'),
            headers: _headers(),
          )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final data = json['data'] as List? ?? [];
        _modelIds = data
            .map((m) => (m as Map<String, dynamic>)['id'] as String)
            .toList();
        debugPrint('[Hermes] Fetched ${_modelIds.length} models: $_modelIds');
      }
    } catch (e) {
      appLogger.warning('[Hermes] Failed to fetch models: $e');
    }
  }

  @override
  void dispose() {
    _messageController.close();
    _agentEventController.close();
    _client?.close();
    super.dispose();
  }
}
