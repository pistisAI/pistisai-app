import 'dart:convert';

import '../../models/conversation.dart';
import '../../models/message.dart';
import 'channel.dart';

/// Hub-owned conversation channels (#1065).
///
/// The Drift database is the canonical store. A harness transcript is never
/// this store: runtime session ids live in [Conversation.runtimeSessions]
/// only as an adapter mapping.
abstract interface class ChannelStore {
  /// Every channel, oldest update first.
  Future<List<Conversation>> loadAll();

  /// Replaces the stored set with [conversations].
  Future<void> replaceAll(List<Conversation> conversations);

  /// Inserts or replaces one channel. Other channels stay.
  Future<void> upsert(Conversation conversation);

  Future<void> delete(String channelId);

  Future<void> clear();

  /// True after the encrypted JSON file has been imported once.
  Future<bool> isJsonImported();

  Future<void> markJsonImported();

  /// True after the legacy Hermes transcript was copied into [channelId].
  Future<bool> isHermesHistoryImported(String channelId);

  Future<void> markHermesHistoryImported(String channelId);
}

/// In-memory [ChannelStore] for tests and for callers with no database.
class InMemoryChannelStore implements ChannelStore {
  final Map<String, Conversation> _channels = {};
  final Set<String> _hermesImported = {};
  bool _jsonImported = false;

  @override
  Future<List<Conversation>> loadAll() async {
    final list = _channels.values.toList()
      ..sort((a, b) => a.updatedAt.compareTo(b.updatedAt));
    return list;
  }

  @override
  Future<void> replaceAll(List<Conversation> conversations) async {
    _channels.clear();
    for (final conversation in conversations) {
      _channels[_key(conversation)] = conversation;
    }
  }

  @override
  Future<void> upsert(Conversation conversation) async {
    _channels[_key(conversation)] = conversation;
  }

  @override
  Future<void> delete(String channelId) async {
    _channels.remove(channelId);
  }

  @override
  Future<void> clear() async {
    _channels.clear();
  }

  @override
  Future<bool> isJsonImported() async => _jsonImported;

  @override
  Future<void> markJsonImported() async {
    _jsonImported = true;
  }

  @override
  Future<bool> isHermesHistoryImported(String channelId) async =>
      _hermesImported.contains(channelId);

  @override
  Future<void> markHermesHistoryImported(String channelId) async {
    _hermesImported.add(channelId);
  }

  static String _key(Conversation conversation) => conversation.channelId;
}

/// Reads a conversation row written by [conversationToRow].
Conversation conversationFromRow({
  required String id,
  required String kindName,
  required String title,
  required String createdAt,
  required String updatedAt,
  required String? model,
  required String metadataJson,
  required String runtimeSessionsJson,
  required List<Message> messages,
}) {
  final kind = ChannelKind.values.where((value) => value.name == kindName);
  final created = DateTime.tryParse(createdAt) ?? DateTime.now().toUtc();
  return Conversation(
    id: id,
    title: title,
    messages: messages,
    createdAt: created,
    updatedAt: DateTime.tryParse(updatedAt) ?? created,
    model: model,
    metadata: _objectMap(metadataJson),
    runtimeSessions: _stringMap(runtimeSessionsJson),
    channel: ConversationChannel(
      id: id,
      kind: kind.isEmpty ? ChannelKind.direct : kind.first,
      title: title,
      createdAt: created,
    ),
  );
}

Map<String, dynamic> _objectMap(String raw) {
  try {
    final decoded = jsonDecode(raw);
    if (decoded is Map) {
      return Map<String, dynamic>.from(decoded);
    }
  } catch (_) {}
  return <String, dynamic>{};
}

Map<String, String> _stringMap(String raw) {
  try {
    final decoded = jsonDecode(raw);
    if (decoded is Map) {
      final sessions = <String, String>{};
      for (final entry in decoded.entries) {
        final value = entry.value;
        if (entry.key is String && value is String && value.isNotEmpty) {
          sessions[entry.key as String] = value;
        }
      }
      return sessions;
    }
  } catch (_) {}
  return const {};
}
