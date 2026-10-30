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
    final message = messageFromHermesSessionRow(Map<String, dynamic>.from(item));
    if (message != null) messages.add(message);
  }
  messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
  return messages;
}

/// The harness transcript is the shared conversation. Local rows that the
/// harness has not stored yet (a message just sent on this device) stay
/// at the end. A local-only welcome message is dropped once the harness
/// has real history.
///
/// Local messages use app-generated IDs while harness rows use server IDs,
/// so ID-only deduplication is not enough. We also match by content + role
/// + timestamp proximity so a freshly-sent message that already appears
/// in the harness is not rendered twice.
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

  // Build a lookup of harness messages by (role, content, nearby timestamp)
  // so local messages that already exist in the harness are not duplicated.
  final harnessByContent = <String, List<Message>>{};
  for (final message in harness) {
    final key = '${message.role.name}:${message.content}';
    harnessByContent.putIfAbsent(key, () => []).add(message);
  }

  final pending = local.where((message) {
    if (message.role == MessageRole.system) return false;
    if (ids.contains(message.id)) return false;

    final key = '${message.role.name}:${message.content}';
    final candidates = harnessByContent[key];
    if (candidates != null) {
      // If a harness message has the same content and role and its
      // timestamp is within 2 seconds, treat the local message as a
      // duplicate of the harness row.
      final hasNearbyHarness = candidates.any(
        (h) => message.timestamp.difference(h.timestamp).inSeconds.abs() <= 2,
      );
      if (hasNearbyHarness) return false;
    }

    return !message.timestamp.isBefore(newest);
  }).toList();

  return [...harness, ...pending];
}

Message? messageFromHermesSessionRow(Map<String, dynamic> row) {
  if (row['display_kind'] == 'hidden') return null;
  final role = _role(row['role']);
  if (role == null) return null;
  final content = textFromHermesContent(row['content']);
  if (content == null || content.trim().isEmpty) return null;
  final id = row['id']?.toString();
  if (id == null || id.isEmpty) return null;

  return Message(
    id: id,
    content: content,
    reasoning: textFromHermesContent(row['reasoning']) ??
        textFromHermesContent(row['reasoning_content']),
    role: role,
    timestamp: hermesTimestamp(row['timestamp']),
    model: role == MessageRole.assistant ? 'hermes-agent' : null,
  );
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
