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
import '../agent_session/harness_event.dart';
import '../agent_session/hermes_owned_session.dart';
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
  String? _apiKey;

  /// HTTP client — kept alive for connection pooling.
  http.Client? _client;

  /// How long the shared transcript may be unreadable before the turn fails.
  ///
  /// Bounds the "Thinking…" placeholder when every poll returns null (hub
  /// unreachable / read error), instead of waiting out the full reply window.
  final Duration _transcriptFetchTimeout;

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
  ///
  /// This is an adapter mapping only: the conversation itself lives in the
  /// app's local store (#1065). The mapping is reused across polls and
  /// re-resolved when the runtime answers 404, when it is older than
  /// [_mappingRefreshInterval], or when a turn's reply does not show up in
  /// the mapped session (the runtime may have started a new session).
  final Map<String, String> _runtimeSessionsByConversation = {};
  final Map<String, DateTime> _runtimeSessionBoundAt = {};
  final Duration _mappingRefreshInterval;

  /// Still accepted by callers. Owned sessions are not re-listed when it elapses.
  @visibleForTesting
  Duration get mappingRefreshInterval => _mappingRefreshInterval;

  /// Chats already logged as "no runtime session yet", so the pre-first-turn
  /// state is logged once instead of on every poll.
  final Set<String> _loggedNoSession = {};

  /// Hermes session currently bound to [conversationId], if any.
  String? runtimeSessionIdFor(String conversationId) =>
      _runtimeSessionsByConversation[conversationId];

  /// Restores a mapping saved in the local conversation store, so a restart
  /// does not have to resolve it again. Ignored when one is already bound.
  void restoreRuntimeSession(String conversationId, String? sessionId) {
    if (_runtimeSessionsByConversation.containsKey(conversationId)) return;
    _bindRuntimeSession(conversationId, sessionId);
  }

  /// Forgets the mapping for [conversationId] (for example after a local
  /// data wipe). The next read resolves it again.
  void clearRuntimeSession(String conversationId) {
    _runtimeSessionsByConversation.remove(conversationId);
    _runtimeSessionBoundAt.remove(conversationId);
    _loggedNoSession.remove(conversationId);
  }

  void _bindRuntimeSession(String conversationId, String? sessionId) {
    final trimmed = sessionId?.trim();
    if (trimmed == null || trimmed.isEmpty) return;
    _runtimeSessionsByConversation[conversationId] = trimmed;
    _runtimeSessionBoundAt[conversationId] = DateTime.now();
    _loggedNoSession.remove(conversationId);
  }

  String _sessionForConversation(String conversationId) =>
      _runtimeSessionsByConversation[conversationId] ?? conversationId;

  HermesStreamingService({
    String? baseUrl,
    String? apiKey,
    http.Client? client,
    Duration transcriptFetchTimeout = const Duration(seconds: 30),
    Duration mappingRefreshInterval = const Duration(minutes: 1),
  })  : _baseUrl = baseUrl ?? 'http://127.0.0.1:8642',
        _apiKey = apiKey,
        _client = client,
        _transcriptFetchTimeout = transcriptFetchTimeout,
        _mappingRefreshInterval = mappingRefreshInterval;

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

  /// Apply a bearer key after pairing with a remote hub (#981). Without
  /// this the live client omits Authorization until the app restarts.
  void updateApiKey(String key) {
    final trimmed = key.trim();
    if (trimmed.isEmpty) return;
    _apiKey = trimmed;
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

    yield* _streamViaOwnedSession(
      prompt: prompt,
      model: model,
      conversationId: conversationId,
    );
  }

  HermesOwnedSessionApi _ownedApi() {
    return HermesOwnedSessionApi(
      baseUrl: _baseUrl,
      headers: _headers,
      client: _client ?? http.Client(),
    );
  }

  /// Creates an API-server-owned Hermes session when this channel has none.
  ///
  /// The id is an adapter mapping. It is not the channel's identity.
  Future<String?> ensureOwnedSession(String channelId, {String? title}) async {
    final mapped = _runtimeSessionsByConversation[channelId];
    if (mapped != null && mapped.isNotEmpty) return mapped;
    try {
      final created = await _ownedApi().create(
        title: title ?? channelId,
        timeout: _transcriptFetchTimeout,
      );
      if (created == null) return null;
      _bindRuntimeSession(channelId, created);
      return created;
    } catch (e) {
      appLogger.error('[Hermes] Could not create an API session', error: e);
      return null;
    }
  }

  /// One synchronous turn on an API-server-owned session (#1066).
  Future<String?> postOwnedSessionChat({
    required String sessionId,
    required String message,
  }) async {
    try {
      return await _ownedApi().chat(sessionId: sessionId, message: message);
    } catch (e) {
      appLogger.error('[Hermes] Session chat failed', error: e);
      return null;
    }
  }

  /// Ends the API-server session. A missing session counts as ended.
  Future<bool> deleteOwnedSession(String sessionId) async {
    try {
      return await _ownedApi().delete(sessionId);
    } catch (e) {
      appLogger.error('[Hermes] Session delete failed', error: e);
      return false;
    }
  }

  /// Token and tool events for one turn (#1068).
  Stream<HarnessEvent> streamOwnedSessionChat({
    required String channelId,
    required String sessionId,
    required String message,
  }) {
    return _ownedApi().chatStream(
      channelId: channelId,
      sessionId: sessionId,
      message: message,
    );
  }

  /// The pre-migration pistisai transcript, ignoring any API-server session
  /// this app created. Used once to import history (#1067).
  Future<List<Message>?> fetchLegacyPistisaiTranscript() async {
    try {
      final id = await _resolvePistisaiSessionId();
      if (id == null) return const [];
      final client = _client ?? http.Client();
      final response = await client.get(
        Uri.parse(
          '$_baseUrl/api/sessions/${Uri.encodeComponent(id)}/messages'
          '?order=oldest&limit=500',
        ),
        headers: {..._headers(), 'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 8));
      if (response.statusCode == 404) return const [];
      if (response.statusCode != 200) return null;
      return messagesFromHermesSessionBody(response.body);
    } catch (e) {
      appLogger.error('[Hermes] Legacy transcript import failed', error: e);
      return null;
    }
  }

  /// Post one turn to an API-server-owned session and yield the reply.
  ///
  /// When [streamTokens] is false the reply is one chunk from
  /// `POST /api/sessions/{id}/chat`. When it is true, deltas come from
  /// `/chat/stream`.
  Stream<StreamingMessage> _streamViaOwnedSession({
    required String prompt,
    required String model,
    required String conversationId,
    bool streamTokens = true,
  }) async* {
    final messageId = DateTime.now().millisecondsSinceEpoch.toString();
    var sequence = 0;
    final sessionId = await ensureOwnedSession(conversationId);
    if (sessionId == null) {
      final errorMsg = StreamingMessage.error(
        id: messageId,
        conversationId: conversationId,
        error: '${Brand.current.productName} could not open a Hermes session. '
            'Check the hub connection and try again.',
        sequence: sequence++,
      );
      _messageController.add(errorMsg);
      yield errorMsg;
      return;
    }

    if (!streamTokens) {
      final text = await postOwnedSessionChat(
        sessionId: sessionId,
        message: prompt,
      );
      if (text == null) {
        final errorMsg = StreamingMessage.error(
          id: messageId,
          conversationId: conversationId,
          error: '${Brand.current.productName} could not read the agent '
              'transcript. Check the hub connection and try again.',
          sequence: sequence++,
        );
        _messageController.add(errorMsg);
        yield errorMsg;
        return;
      }
      if (text.isNotEmpty) {
        final chunk = StreamingMessage.chunk(
          id: messageId,
          conversationId: conversationId,
          chunk: text,
          sequence: sequence++,
          model: model == 'default' ? 'hermes-agent' : model,
        );
        _messageController.add(chunk);
        yield chunk;
      }
      final complete = StreamingMessage.complete(
        id: messageId,
        conversationId: conversationId,
        sequence: sequence++,
        model: model == 'default' ? 'hermes-agent' : model,
      );
      _messageController.add(complete);
      yield complete;
      return;
    }

    var sawText = false;
    await for (final event in streamOwnedSessionChat(
      channelId: conversationId,
      sessionId: sessionId,
      message: prompt,
    )) {
      switch (event) {
        case HarnessDelta(:final text):
          sawText = true;
          final chunk = StreamingMessage.chunk(
            id: messageId,
            conversationId: conversationId,
            chunk: text,
            sequence: sequence++,
            model: model == 'default' ? 'hermes-agent' : model,
          );
          _messageController.add(chunk);
          yield chunk;
        case HarnessToolStarted(:final toolName):
          _agentEventController.add(AgentToolStarted(
            runId: sessionId,
            timestamp: DateTime.now().millisecondsSinceEpoch / 1000,
            tool: toolName,
          ));
        case HarnessToolFinished(:final toolName, :final failed):
          _agentEventController.add(AgentToolCompleted(
            runId: sessionId,
            timestamp: DateTime.now().millisecondsSinceEpoch / 1000,
            tool: toolName,
            duration: 0,
            isError: failed,
          ));
        case HarnessMessageCompleted():
          final complete = StreamingMessage.complete(
            id: messageId,
            conversationId: conversationId,
            sequence: sequence++,
            model: model == 'default' ? 'hermes-agent' : model,
          );
          _messageController.add(complete);
          yield complete;
          return;
        case HarnessError(:final message):
          final errorMsg = StreamingMessage.error(
            id: messageId,
            conversationId: conversationId,
            error: message,
            sequence: sequence++,
          );
          _messageController.add(errorMsg);
          yield errorMsg;
          return;
      }
    }
    if (!sawText) {
      final errorMsg = StreamingMessage.error(
        id: messageId,
        conversationId: conversationId,
        error: '${Brand.current.productName} channel produced no assistant reply',
        sequence: sequence,
      );
      _messageController.add(errorMsg);
      yield errorMsg;
    }
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
    await for (final message in _streamViaOwnedSession(
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
  ///
  /// For the pistisai channel, the Hermes session id is read from the adapter
  /// mapping. With no mapping, it is resolved; when nothing is found (no
  /// first turn yet) no transcript request is made at all. [refreshMapping]
  /// forces a new resolution even when a mapping exists.
  Future<List<Message>?> fetchSessionMessages(
    String sessionId, {
    bool refreshMapping = false,
  }) async {
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
      // session id (e.g. `20261104_190859_119a1e2b`, source=pistisai). That
      // id is kept as an adapter mapping and reused across polls.
      final isChannel = sessionId == Conversation.pistisaiChannelId;
      String targetId;
      if (isChannel) {
        // The chat ID is an app-owned channel, not a runtime session. Before
        // the first turn there is nothing to read: skip the short-ID poll
        // entirely instead of generating a guaranteed 404 (#1065).
        final mapped = await _mappedPistisaiSession(
          sessionId,
          refresh: refreshMapping,
        );
        if (mapped == null) return const [];
        targetId = mapped;
      } else {
        targetId = runtimeId;
      }
      http.Response response = await getMessages(targetId);
      if (response.statusCode == 404 && isChannel) {
        // The mapped session is gone (reset or removed on the runtime):
        // resolve once more. Never fall back to the short channel id.
        clearRuntimeSession(sessionId);
        final fresh = await _mappedPistisaiSession(sessionId, refresh: true);
        if (fresh != null && fresh != targetId) {
          targetId = fresh;
          response = await getMessages(targetId);
        } else if (fresh != null) {
          clearRuntimeSession(sessionId);
        }
      } else if (response.statusCode == 404 && targetId != sessionId) {
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
      // The channel's mapping comes from resolution only, so a body that
      // echoes the short channel id can never become the mapping.
      if (!isChannel && decoded is Map && decoded['session_id'] is String) {
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

  /// The API-server session already bound to [chatId].
  ///
  /// This does not list `source=pistisai` sessions. That listing is only for
  /// the one-time legacy import. No mapping means there is nothing to read.
  Future<String?> _mappedPistisaiSession(
    String chatId, {
    bool refresh = false,
  }) async {
    if (refresh) {
      clearRuntimeSession(chatId);
      return null;
    }
    return _runtimeSessionsByConversation[chatId];
  }

  /// Resolve the Hermes session id currently backing the pistisai DM
  /// (session key `agent:main:pistisai:dm:pistisai`): the most recently
  /// active `source=pistisai` session.
  Future<String?> _resolvePistisaiSessionId() async {
    try {
      final client = _client ?? http.Client();
      final response = await client.get(
        // Ask for this app's own chat only: other chats can also carry
        // source=pistisai, and the most recent of those is not ours (#629).
        Uri.parse(
          '$_baseUrl/api/sessions?source=pistisai'
          '&chat=${Conversation.pistisaiChannelId}&limit=20',
        ),
        headers: {..._headers(), 'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) return null;
      final decoded = jsonDecode(response.body);
      final data = decoded is Map ? decoded['data'] : null;
      if (data is! List) return null;
      String? bestId;
      double bestActive = double.negativeInfinity;
      for (final row in data) {
        if (row is! Map) continue;
        if (row['source'] != null && row['source'] != 'pistisai') continue;
        // A runtime that ignores the chat filter still tells us which chat a
        // row belongs to; never adopt another chat's session.
        final chat = row['chat'] ?? row['chat_id'];
        if (chat != null && chat != Conversation.pistisaiChannelId) continue;
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

  Map<String, dynamic>? _personalityPayload;
  bool _personalityPending = false;

  /// Sends the personality set in the app (name, four traits, evolution
  /// stage) to the pistisai plugin on the user's Hermes, which adds it to each
  /// turn so the sliders change how the agent talks.
  ///
  /// Best-effort. When Hermes is not reachable yet, the personality is kept
  /// and sent again before the next chat message. Returns true once applied.
  Future<bool> reportPersonality({
    required String agentName,
    required Map<String, double> traits,
    required String evolutionStage,
  }) {
    _personalityPayload = {
      'agent_name': agentName,
      'traits': traits,
      'evolution_stage': evolutionStage,
    };
    _personalityPending = true;
    return _flushPersonality();
  }

  Future<bool> _flushPersonality() async {
    final payload = _personalityPayload;
    if (payload == null || !_personalityPending) return false;
    try {
      _client ??= http.Client();
      final response = await _client!
          .post(
            Uri.parse('$_baseUrl/api/pistisai/personality'),
            headers: {..._headers(), 'Accept': 'application/json'},
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        _personalityPending = false;
        return true;
      }
      if (response.statusCode == 404) {
        // Hermes runs a plugin version without this route: stop retrying.
        _personalityPending = false;
      }
      appLogger.warning(
        '[Hermes] personality not applied (HTTP ${response.statusCode})',
      );
      return false;
    } catch (e) {
      appLogger.warning('[Hermes] personality not applied yet: $e');
      return false;
    }
  }

  Map<String, String> _headers() {
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'text/event-stream',
    };
    final apiKey = _apiKey;
    if (apiKey != null && apiKey.isNotEmpty) {
      headers['Authorization'] = 'Bearer $apiKey';
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
