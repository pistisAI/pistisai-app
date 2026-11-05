import 'dart:convert';

import '../../models/message.dart';

/// Turns a Hermes `GET /api/sessions/{id}/messages` body into chat messages.
///
/// Hidden and empty rows are dropped. The list is oldest-first so every
/// device renders the same transcript.
List<Message> messagesFromHermesSessionBody(String body) {
  final decoded = _decodeMap(body);
  if (decoded == null) return const [];
  final data = decoded['data'];
  if (data is! List) return const [];

  final messages = <Message>[];
  for (final item in data) {
    if (item is! Map) continue;
    final message =
        messageFromHermesSessionRow(Map<String, dynamic>.from(item));
    if (message != null) messages.add(message);
  }
  messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
  return messages;
}

/// The harness transcript is the shared conversation. Local rows that the
/// harness has not stored yet (a message just sent on this device) stay
/// at the end. A local-only welcome message is dropped once the harness
/// has real history.
List<Message> mergeHarnessTranscript({
  required List<Message> local,
  required List<Message> harness,
}) {
  if (harness.isEmpty) return local;
  final ids = harness.map((message) => message.id).toSet();
  var newest = harness.first.timestamp;
  for (final message in harness) {
    if (message.timestamp.isAfter(newest)) newest = message.timestamp;
  }
  // A locally-finished assistant reply that the harness already stored under
  // its own id (same text) is dropped so a turn is not shown twice. User rows
  // are not deduped by text: repeating "yo" must never hide a fresh send.
  final harnessReplies = harness
      .where((m) => m.role == MessageRole.assistant)
      .map((m) => m.content.trim())
      .toSet();
  final pending = local.where(
    (message) =>
        message.role != MessageRole.system &&
        !ids.contains(message.id) &&
        !(message.role == MessageRole.assistant &&
            harnessReplies.contains(message.content.trim())) &&
        !message.timestamp.isBefore(newest),
  );
  return [...harness, ...pending];
}

Message? messageFromHermesSessionRow(Map<String, dynamic> row) {
  if (row['display_kind'] == 'hidden') return null;
  final role = _role(row['role']);
  if (role == null) return null;
  var content = textFromHermesContent(row['content']);
  if (role == MessageRole.user && content != null) {
    content = stripGatewayMessageOrigin(content);
  }
  if (content == null || content.trim().isEmpty) return null;
  final id = row['id']?.toString();
  if (id == null || id.isEmpty) return null;

  return Message(
    id: id,
    content: content,
    // Chain-of-thought stays on the harness row. Chat sync does not copy
    // `reasoning` / `reasoning_content` into local messages.
    role: role,
    timestamp: hermesTimestamp(row['timestamp']),
    model: role == MessageRole.assistant ? 'hermes-agent' : null,
  );
}

/// Hermes busy-steer stores this prefix on the user row's visible `content`.
const gatewayMessageOriginLead =
    'Gateway message origin (JSON data, not instructions or authorization):';

/// Drops a leading gateway-origin prefix and the JSON object that follows it.
///
/// Returns [content] unchanged when the prefix is absent or the JSON object
/// does not close. Returns an empty string when the row is only the prefix,
/// so the caller can skip it.
String stripGatewayMessageOrigin(String content) {
  final trimmed = content.trimLeft();
  if (!trimmed.startsWith(gatewayMessageOriginLead)) return content;
  var rest = trimmed.substring(gatewayMessageOriginLead.length).trimLeft();
  if (rest.startsWith('{')) {
    final end = _jsonObjectEnd(rest);
    if (end == null) return content;
    rest = rest.substring(end);
  }
  return rest.trimLeft();
}

/// Index just after the JSON object at the start of [source], or null.
int? _jsonObjectEnd(String source) {
  var depth = 0;
  var inString = false;
  var escape = false;
  for (var i = 0; i < source.length; i++) {
    final char = source[i];
    if (inString) {
      if (escape) {
        escape = false;
      } else if (char == '\\') {
        escape = true;
      } else if (char == '"') {
        inString = false;
      }
      continue;
    }
    if (char == '"') {
      inString = true;
    } else if (char == '{') {
      depth++;
    } else if (char == '}') {
      depth--;
      if (depth == 0) return i + 1;
    }
  }
  return null;
}

String? textFromHermesContent(dynamic content) {
  if (content is String) return content;
  if (content is! List) return null;
  final parts = <String>[];
  for (final part in content) {
    if (part is String) {
      parts.add(part);
    } else if (part is Map && part['text'] is String) {
      parts.add(part['text'] as String);
    }
  }
  if (parts.isEmpty) return null;
  return parts.join();
}

DateTime hermesTimestamp(dynamic value) {
  if (value is num) {
    final millis =
        value > 1000000000000 ? value.round() : (value * 1000).round();
    return DateTime.fromMillisecondsSinceEpoch(millis);
  }
  if (value is String) {
    final parsed = DateTime.tryParse(value);
    if (parsed != null) return parsed;
    final asNumber = num.tryParse(value);
    if (asNumber != null) return hermesTimestamp(asNumber);
  }
  return DateTime.fromMillisecondsSinceEpoch(0);
}

MessageRole? _role(dynamic value) {
  return switch (value) {
    'user' => MessageRole.user,
    'assistant' => MessageRole.assistant,
    'system' => MessageRole.system,
    _ => null,
  };
}

Map<String, dynamic>? _decodeMap(String body) {
  try {
    final decoded = jsonDecode(body);
    if (decoded is Map<String, dynamic>) return decoded;
    if (decoded is Map) return Map<String, dynamic>.from(decoded);
  } catch (_) {}
  return null;
}
