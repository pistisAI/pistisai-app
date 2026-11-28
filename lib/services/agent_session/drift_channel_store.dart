import 'dart:convert';

import 'package:drift/drift.dart';

import '../../database/drift_local_brain.dart' hide Conversation, Message;
import '../../database/hub_channel_schema.dart';
import '../../models/conversation.dart';
import '../../models/message.dart';
import 'channel_store.dart';

/// [ChannelStore] backed by the Drift/SQLite local brain (#1065).
class DriftChannelStore implements ChannelStore {
  DriftChannelStore(this._db);

  final LocalBrain _db;
  bool _ready = false;

  Future<void> _ensure() async {
    if (_ready) return;
    await _db.ensureHubChannelTables();
    _ready = true;
  }

  @override
  Future<List<Conversation>> loadAll() async {
    await _ensure();
    final rows = await _db.customSelect(
      'SELECT id, kind, title, created_at, updated_at, model, '
      'metadata_json, runtime_sessions_json '
      'FROM hub_channels ORDER BY updated_at ASC',
    ).get();
    final conversations = <Conversation>[];
    for (final row in rows) {
      final id = row.read<String>('id');
      conversations.add(conversationFromRow(
        id: id,
        kindName: row.read<String>('kind'),
        title: row.read<String>('title'),
        createdAt: row.read<String>('created_at'),
        updatedAt: row.read<String>('updated_at'),
        model: row.readNullable<String>('model'),
        metadataJson: row.read<String>('metadata_json'),
        runtimeSessionsJson: row.read<String>('runtime_sessions_json'),
        messages: await _messages(id),
      ));
    }
    return conversations;
  }

  Future<List<Message>> _messages(String channelId) async {
    final rows = await _db.customSelect(
      'SELECT payload_json FROM hub_channel_messages '
      'WHERE channel_id = ? ORDER BY position ASC',
      variables: [Variable<String>(channelId)],
    ).get();
    final messages = <Message>[];
    for (final row in rows) {
      final decoded = jsonDecode(row.read<String>('payload_json'));
      if (decoded is Map) {
        messages.add(Message.fromJson(Map<String, dynamic>.from(decoded)));
      }
    }
    return messages;
  }

  @override
  Future<void> replaceAll(List<Conversation> conversations) async {
    await _ensure();
    final imported = <String, bool>{};
    for (final conversation in conversations) {
      imported[conversation.channelId] =
          await isHermesHistoryImported(conversation.channelId);
    }
    await _db.transaction(() async {
      await _db.customStatement('DELETE FROM hub_channel_messages');
      await _db.customStatement('DELETE FROM hub_channels');
      for (final conversation in conversations) {
        await _insert(
          conversation,
          hermesHistoryImported: imported[conversation.channelId] ?? false,
        );
      }
    });
  }

  @override
  Future<void> upsert(Conversation conversation) async {
    await _ensure();
    final imported = await isHermesHistoryImported(conversation.channelId);
    await _db.transaction(() async {
      await _deleteRows(conversation.channelId);
      await _insert(conversation, hermesHistoryImported: imported);
    });
  }

  @override
  Future<void> delete(String channelId) async {
    await _ensure();
    await _db.transaction(() async {
      await _deleteRows(channelId);
    });
  }

  @override
  Future<void> clear() async {
    await _ensure();
    await _db.transaction(() async {
      await _db.customStatement('DELETE FROM hub_channel_messages');
      await _db.customStatement('DELETE FROM hub_channels');
    });
  }

  Future<void> _deleteRows(String channelId) async {
    await _db.customStatement(
      'DELETE FROM hub_channel_messages WHERE channel_id = ?',
      [channelId],
    );
    await _db.customStatement(
      'DELETE FROM hub_channels WHERE id = ?',
      [channelId],
    );
  }

  Future<void> _insert(
    Conversation conversation, {
    required bool hermesHistoryImported,
  }) async {
    final channel = conversation.channel;
    await _db.customStatement(
      'INSERT INTO hub_channels ('
      'id, kind, title, created_at, updated_at, model, '
      'metadata_json, runtime_sessions_json, hermes_history_imported'
      ') VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)',
      [
        channel.id,
        channel.kind.name,
        conversation.title,
        conversation.createdAt.toUtc().toIso8601String(),
        conversation.updatedAt.toUtc().toIso8601String(),
        conversation.model,
        jsonEncode(conversation.metadata),
        jsonEncode(conversation.runtimeSessions),
        hermesHistoryImported ? 1 : 0,
      ],
    );
    var position = 0;
    for (final message in conversation.messages) {
      await _db.customStatement(
        'INSERT INTO hub_channel_messages ('
        'channel_id, position, message_id, payload_json'
        ') VALUES (?, ?, ?, ?)',
        [
          channel.id,
          position,
          message.id,
          jsonEncode(message.toJson()),
        ],
      );
      position++;
    }
  }

  @override
  Future<bool> isJsonImported() async {
    await _ensure();
    final rows = await _db.customSelect(
      'SELECT flag_value FROM hub_store_flags WHERE flag_key = ?',
      variables: [Variable<String>(hubJsonImportedFlag)],
    ).get();
    return rows.isNotEmpty && rows.single.read<String>('flag_value') == '1';
  }

  @override
  Future<void> markJsonImported() async {
    await _ensure();
    await _db.customStatement(
      'INSERT INTO hub_store_flags (flag_key, flag_value) VALUES (?, ?) '
      'ON CONFLICT(flag_key) DO UPDATE SET flag_value = excluded.flag_value',
      [hubJsonImportedFlag, '1'],
    );
  }

  @override
  Future<bool> isHermesHistoryImported(String channelId) async {
    await _ensure();
    final rows = await _db.customSelect(
      'SELECT hermes_history_imported FROM hub_channels WHERE id = ?',
      variables: [Variable<String>(channelId)],
    ).get();
    if (rows.isEmpty) return false;
    return rows.single.read<int>('hermes_history_imported') == 1;
  }

  @override
  Future<void> markHermesHistoryImported(String channelId) async {
    await _ensure();
    await _db.customStatement(
      'UPDATE hub_channels SET hermes_history_imported = 1 WHERE id = ?',
      [channelId],
    );
  }
}
