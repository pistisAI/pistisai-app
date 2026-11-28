import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:pistisai/models/conversation.dart';
import 'package:pistisai/services/agent_session/channel.dart';
import 'package:pistisai/services/agent_session/conversation_runtime_session_store.dart';
import 'package:pistisai/services/agent_session/runtime_session_map.dart';

/// Conversations carry a channel identity (#1067) and keep runtime session
/// ids in `runtimeSessions`, read by `RuntimeSessionMap` (#1066). Files
/// written before either existed still load.
void main() {
  /// A conversation file as the app wrote it before this change, including
  /// the #1086 Hermes mapping in metadata.
  Map<String, dynamic> legacyFile({Map<String, dynamic>? metadata}) =>
      jsonDecode(jsonEncode({
        'id': Conversation.pistisaiChannelId,
        'title': 'Agent',
        'messages': [
          {
            'id': 'm1',
            'content': 'hello',
            'role': 'user',
            'timestamp': '2026-11-20T10:00:00.000',
          },
        ],
        'createdAt': '2026-11-01T09:00:00.000',
        'updatedAt': '2026-11-20T10:00:00.000',
        'model': 'default',
        'metadata': metadata ?? {},
      })) as Map<String, dynamic>;

  group('channel identity', () {
    test('an old conversation file loads and gains the default channel', () {
      final loaded = Conversation.fromJson(legacyFile());

      expect(loaded.id, Conversation.pistisaiChannelId);
      expect(loaded.messages.single.content, 'hello');
      expect(loaded.channelId, Conversation.pistisaiChannelId);
      expect(loaded.channel.kind, ChannelKind.direct);
      expect(loaded.channel.title, 'Agent');
      expect(
        loaded.channel.createdAt,
        DateTime.parse('2026-11-01T09:00:00.000').toUtc(),
      );

      // The next save writes the channel, and it reads back the same.
      final saved = jsonDecode(jsonEncode(loaded.toJson()));
      expect((saved as Map)['channel'], isA<Map<dynamic, dynamic>>());
      final reloaded = Conversation.fromJson(saved as Map<String, dynamic>);
      expect(reloaded.channel, loaded.channel);
    });

    test('the main channel is a stored direct channel that keeps its title',
        () {
      final main = Conversation.mainChannel(agentName: 'Nova');
      expect(main.channel.kind, ChannelKind.direct);
      expect(main.channelId, Conversation.pistisaiChannelId);

      final renamed = main.updateTitle('Orion');
      expect(renamed.channel.title, 'Orion');
      expect(renamed.channel.createdAt, main.channel.createdAt);
    });

    test('an unreadable stored channel falls back to the default one', () {
      final file = legacyFile()..['channel'] = {'id': 'x', 'kind': 'nope'};
      final loaded = Conversation.fromJson(file);
      expect(loaded.channelId, Conversation.pistisaiChannelId);
      expect(loaded.channel.kind, ChannelKind.direct);
    });
  });

  group('runtime session migration', () {
    test('the #1086 metadata mapping moves to runtimeSessions', () {
      final loaded = Conversation.fromJson(legacyFile(metadata: {
        Conversation.runtimeSessionsKey: {
          'hermes': {'sessionId': 'gen-1'},
        },
        'other': 'kept',
      }));

      expect(loaded.runtimeSessions, {'hermes': 'gen-1'});
      expect(loaded.runtimeSessionId('hermes'), 'gen-1');
      expect(
        loaded.metadata.containsKey(Conversation.runtimeSessionsKey),
        isFalse,
      );
      expect(loaded.metadata['other'], 'kept');

      final saved = loaded.toJson();
      expect(saved['runtimeSessions'], {'hermes': 'gen-1'});
      expect(
        (saved['metadata'] as Map).containsKey(Conversation.runtimeSessionsKey),
        isFalse,
      );
    });

    test('the new field wins, so a cleared mapping never comes back', () {
      final file = legacyFile(metadata: {
        Conversation.runtimeSessionsKey: {
          'hermes': {'sessionId': 'stale'},
        },
      })
        ..['runtimeSessions'] = <String, dynamic>{};

      expect(Conversation.fromJson(file).runtimeSessions, isEmpty);
    });

    test('RuntimeSessionMap reads the migrated mapping and saves onto the '
        'conversation', () async {
      var conversation = Conversation.fromJson(legacyFile(metadata: {
        Conversation.runtimeSessionsKey: {
          'hermes': {'sessionId': 'gen-1'},
        },
      }));
      final map = await RuntimeSessionMap.load(
        ConversationRuntimeSessionStore(
          read: () => conversation,
          write: (updated) => conversation = updated,
        ),
      );

      expect(
        map.runtimeSessionFor(Conversation.pistisaiChannelId, 'hermes'),
        'gen-1',
      );

      await map.bind(Conversation.pistisaiChannelId, 'hermes', 'gen-2');
      expect(conversation.runtimeSessions, {'hermes': 'gen-2'});
      final reloaded = Conversation.fromJson(
        jsonDecode(jsonEncode(conversation.toJson())) as Map<String, dynamic>,
      );
      expect(reloaded.runtimeSessionId('hermes'), 'gen-2');

      await map.clear(Conversation.pistisaiChannelId);
      expect(conversation.runtimeSessions, isEmpty);
    });
  });
}
