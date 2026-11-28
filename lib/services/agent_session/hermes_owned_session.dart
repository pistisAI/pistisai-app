import 'dart:convert';

import 'package:http/http.dart' as http;

import 'harness_event.dart';

/// Id from `POST /api/sessions` (`{"session": {"id": ...}}`).
String? ownedSessionIdFromBody(Object? decoded) {
  if (decoded is! Map) return null;
  final session = decoded['session'];
  if (session is Map) {
    final id = session['id'];
    if (id is String && id.trim().isNotEmpty) return id.trim();
  }
  final direct = decoded['id'] ?? decoded['session_id'];
  if (direct is String && direct.trim().isNotEmpty) return direct.trim();
  return null;
}

/// Assistant text from `POST /api/sessions/{id}/chat`.
String? ownedSessionReplyFromBody(Object? decoded) {
  if (decoded is! Map) return null;
  final message = decoded['message'];
  if (message is Map && message['content'] is String) {
    return message['content'] as String;
  }
  final content = decoded['content'];
  if (content is String) return content;
  return null;
}

/// One Server-Sent Event from `/api/sessions/{id}/chat/stream`.
class HermesSseEvent {
  const HermesSseEvent({required this.name, required this.data});

  final String name;
  final Map<String, Object?> data;
}

/// Incremental parser. Comment lines (`: keepalive`) are skipped.
class HermesSseParser {
  String _buffer = '';
  String? _name;
  final StringBuffer _data = StringBuffer();

  List<HermesSseEvent> add(String chunk) {
    _buffer += chunk;
    final events = <HermesSseEvent>[];
    while (true) {
      final breakAt = _buffer.indexOf('\n');
      if (breakAt < 0) break;
      var line = _buffer.substring(0, breakAt);
      _buffer = _buffer.substring(breakAt + 1);
      if (line.endsWith('\r')) {
        line = line.substring(0, line.length - 1);
      }
      if (line.isEmpty) {
        if (_name != null || _data.isNotEmpty) {
          events.add(HermesSseEvent(
            name: _name ?? 'message',
            data: _decodeData(_data.toString()),
          ));
        }
        _name = null;
        _data.clear();
        continue;
      }
      if (line.startsWith(':')) continue;
      if (line.startsWith('event:')) {
        _name = line.substring('event:'.length).trim();
      } else if (line.startsWith('data:')) {
        var value = line.substring('data:'.length);
        if (value.startsWith(' ')) value = value.substring(1);
        if (_data.isNotEmpty) _data.write('\n');
        _data.write(value);
      }
    }
    return events;
  }

  static Map<String, Object?> _decodeData(String raw) {
    if (raw.isEmpty) return const {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        return Map<String, Object?>.from(decoded);
      }
    } catch (_) {}
    return <String, Object?>{'raw': raw};
  }
}

/// Translates one session-stream event into a harness event, or null when
/// the chat layer does not need it (keepalives, commentary, run.started).
HarnessEvent? harnessEventForSse({
  required String channelId,
  required HermesSseEvent event,
}) {
  final data = event.data;
  final messageId = data['message_id'] is String
      ? data['message_id'] as String
      : channelId;
  switch (event.name) {
    case 'assistant.delta':
      final text = data['delta'];
      if (text is! String || text.isEmpty) return null;
      return HarnessDelta(
        channelId: channelId,
        messageId: messageId,
        text: text,
      );
    case 'assistant.completed':
      final content = data['content'];
      return HarnessMessageCompleted(
        channelId: channelId,
        message: HarnessMessage(
          id: messageId,
          role: HarnessRole.assistant,
          content: content is String ? content : '',
          createdAt: DateTime.now().toUtc(),
        ),
      );
    case 'tool.started':
    case 'tool.completed':
    case 'tool.failed':
      final toolName = data['tool_name'] is String
          ? data['tool_name'] as String
          : 'tool';
      final toolCallId = data['tool_call_id'] is String
          ? data['tool_call_id'] as String
          : '$messageId:$toolName:${data['seq'] ?? event.name}';
      if (event.name == 'tool.started') {
        return HarnessToolStarted(
          channelId: channelId,
          toolCallId: toolCallId,
          toolName: toolName,
        );
      }
      return HarnessToolFinished(
        channelId: channelId,
        toolCallId: toolCallId,
        toolName: toolName,
        failed: event.name == 'tool.failed',
      );
    case 'run.failed':
    case 'error':
      final message = data['message'] ?? data['error'];
      return HarnessError(
        channelId: channelId,
        message: message is String && message.isNotEmpty
            ? message
            : 'The agent could not complete that request.',
        retryable: event.name == 'error',
      );
    case 'run.cancelled':
      return HarnessError(
        channelId: channelId,
        message: 'The agent stopped that turn.',
      );
    default:
      return null;
  }
}

/// HTTP calls for an API-server-owned Hermes session (#1066, #1068).
class HermesOwnedSessionApi {
  HermesOwnedSessionApi({
    required this.baseUrl,
    required this.headers,
    required this.client,
  });

  final String baseUrl;
  final Map<String, String> Function() headers;
  final http.Client client;

  Future<String?> create({
    String? title,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    final response = await client
        .post(
          Uri.parse('$baseUrl/api/sessions'),
          headers: headers(),
          body: jsonEncode(<String, Object?>{
            'source': 'api_server',
            if (title != null && title.isNotEmpty) 'title': title,
          }),
        )
        .timeout(timeout);
    if (response.statusCode != 200 && response.statusCode != 201) {
      return null;
    }
    return ownedSessionIdFromBody(jsonDecode(response.body));
  }

  Future<String?> chat({
    required String sessionId,
    required String message,
  }) async {
    final response = await client
        .post(
          Uri.parse(
            '$baseUrl/api/sessions/${Uri.encodeComponent(sessionId)}/chat',
          ),
          headers: headers(),
          body: jsonEncode(<String, Object?>{'message': message}),
        )
        .timeout(const Duration(minutes: 10));
    if (response.statusCode != 200) return null;
    return ownedSessionReplyFromBody(jsonDecode(response.body));
  }

  /// True when the session is gone (deleted, or already absent).
  Future<bool> delete(String sessionId) async {
    final response = await client
        .delete(
          Uri.parse(
            '$baseUrl/api/sessions/${Uri.encodeComponent(sessionId)}',
          ),
          headers: headers(),
        )
        .timeout(const Duration(seconds: 15));
    return response.statusCode == 200 ||
        response.statusCode == 204 ||
        response.statusCode == 404;
  }

  /// Opens `POST /api/sessions/{id}/chat/stream` and yields harness events.
  Stream<HarnessEvent> chatStream({
    required String channelId,
    required String sessionId,
    required String message,
  }) async* {
    final request = http.Request(
      'POST',
      Uri.parse(
        '$baseUrl/api/sessions/${Uri.encodeComponent(sessionId)}/chat/stream',
      ),
    );
    request.headers.addAll(headers());
    request.headers['Accept'] = 'text/event-stream';
    request.body = jsonEncode(<String, Object?>{'message': message});
    final response = await client.send(request);
    if (response.statusCode != 200) {
      yield HarnessError(
        channelId: channelId,
        message: 'Hermes did not start the turn (${response.statusCode}).',
        retryable: response.statusCode >= 500,
      );
      return;
    }
    final parser = HermesSseParser();
    var sawTerminal = false;
    await for (final bytes in response.stream) {
      for (final event in parser.add(utf8.decode(bytes))) {
        final harness = harnessEventForSse(channelId: channelId, event: event);
        if (harness == null) continue;
        if (harness is HarnessMessageCompleted || harness is HarnessError) {
          sawTerminal = true;
        }
        yield harness;
      }
    }
    if (!sawTerminal) {
      yield HarnessError(
        channelId: channelId,
        message: 'The agent stream ended before a reply.',
        retryable: true,
      );
    }
  }
}
