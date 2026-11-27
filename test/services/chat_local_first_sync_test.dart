import 'package:flutter_test/flutter_test.dart';
import 'package:pistisai/models/conversation.dart';
import 'package:pistisai/models/message.dart';
import 'package:pistisai/services/streaming_chat_service.dart';

/// The local store owns the conversation (#1065): the runtime sync only adds
/// rows this device does not have, and never drops local history.
void main() {
  DateTime at(int seconds) =>
      DateTime.fromMillisecondsSinceEpoch(1764000000000 + seconds * 1000);

  Message row(String id, MessageRole role, String text, int seconds) =>
      Message(id: id, content: text, role: role, timestamp: at(seconds));

  group('appendRuntimeTranscript', () {
    test('keeps local rows the runtime does not have, even older ones', () {
      final localOnly = row('local-old', MessageRole.user, 'only here', 0);
      final error = row('local-err', MessageRole.assistant, 'failed', 5)
          .copyWith(status: MessageStatus.error);
      final runtime = [row('r1', MessageRole.assistant, 'from runtime', 60)];

      final result = appendRuntimeTranscript(
        local: [localOnly, error],
        runtime: runtime,
      );

      expect(result.changed, isTrue);
      expect(
        result.messages.map((m) => m.id),
        ['local-old', 'local-err', 'r1'],
      );
    });

    test('links a locally written turn instead of duplicating it', () {
      final sent = row('local-u', MessageRole.user, 'yo', 0);
      final reply = row('local-a', MessageRole.assistant, 'Hey there', 4);
      final runtime = [
        row('80213', MessageRole.user, 'yo', 1),
        row('80218', MessageRole.assistant, 'Hey there', 3),
      ];

      final first = appendRuntimeTranscript(
        local: [sent, reply],
        runtime: runtime,
      );
      expect(first.messages.map((m) => m.id), ['local-u', 'local-a']);
      expect(first.messages[0].metadata?[runtimeMessageIdKey], '80213');
      expect(first.messages[1].metadata?[runtimeMessageIdKey], '80218');

      final second = appendRuntimeTranscript(
        local: first.messages,
        runtime: runtime,
      );
      expect(second.changed, isFalse);
      expect(second.messages, hasLength(2));
    });

    test('a repeated message from another device is still added', () {
      final sent = row('local-u', MessageRole.user, 'yo', 0);
      final runtime = [
        row('80213', MessageRole.user, 'yo', 1),
        row('80220', MessageRole.user, 'yo', 30),
      ];

      final result = appendRuntimeTranscript(local: [sent], runtime: runtime);

      expect(result.messages.map((m) => m.id), ['local-u', '80220']);
    });

    test('the same text far apart in time is a different turn', () {
      final sent = row('local-u', MessageRole.user, 'status?', 0);
      final runtime = [row('r9', MessageRole.user, 'status?', 3600)];

      final result = appendRuntimeTranscript(local: [sent], runtime: runtime);

      expect(result.messages.map((m) => m.id), ['local-u', 'r9']);
    });

    test('an imported runtime row is refreshed when it grew', () {
      final imported = row('r1', MessageRole.assistant, 'Working', 0);
      final result = appendRuntimeTranscript(
        local: [imported],
        runtime: [row('r1', MessageRole.assistant, 'Working on it, done.', 0)],
      );

      expect(result.changed, isTrue);
      expect(result.messages.single.content, 'Working on it, done.');
    });

    test('a local user row is never rewritten by the runtime', () {
      final sent = row('local-u', MessageRole.user, 'hello', 0)
          .copyWith(metadata: {runtimeMessageIdKey: 'r1'});
      final result = appendRuntimeTranscript(
        local: [sent],
        runtime: [row('r1', MessageRole.user, 'hello edited', 0)],
      );

      expect(result.messages.single.content, 'hello');
    });

    test('runtime rows are appended without removing local ones', () {
      final local = [
        row('a', MessageRole.user, 'one', 0),
        row('b', MessageRole.assistant, 'two', 1),
        row('c', MessageRole.user, 'three', 2),
      ];
      // The runtime knows only part of the thread (for example after its
      // session was reset), plus a proactive message.
      final runtime = [row('p', MessageRole.assistant, 'reminder', 100)];

      final result = appendRuntimeTranscript(local: local, runtime: runtime);

      expect(result.messages.map((m) => m.id), ['a', 'b', 'c', 'p']);
    });

    test('an empty runtime transcript changes nothing', () {
      final local = [row('a', MessageRole.user, 'one', 0)];
      final result = appendRuntimeTranscript(local: local, runtime: const []);
      expect(result.changed, isFalse);
      expect(result.messages, local);
    });

    test('the welcome row gives way only when the thread has no turns', () {
      final welcome = Message.system(content: 'Welcome', id: 'welcome');
      final runtime = [row('r1', MessageRole.user, 'hi', 0)];

      final fresh = appendRuntimeTranscript(
        local: [welcome],
        runtime: runtime,
      );
      expect(fresh.messages.map((m) => m.id), ['r1']);

      final withTurns = appendRuntimeTranscript(
        local: [welcome, row('l1', MessageRole.user, 'mine', 0)],
        runtime: [row('r2', MessageRole.assistant, 'other', 5)],
      );
      expect(withTurns.messages.map((m) => m.id), ['welcome', 'l1', 'r2']);
    });
  });

  group('Conversation runtime session mapping', () {
    test('is stored in metadata and survives a save', () {
      final conversation = Conversation.mainChannel(agentName: 'Agent')
          .withRuntimeSession('hermes', 'gen-1');

      final restored = Conversation.fromJson(conversation.toJson());

      expect(restored.id, Conversation.pistisaiChannelId);
      expect(restored.runtimeSessionId('hermes'), 'gen-1');
      expect(restored.runtimeSessionId('other'), isNull);
    });

    test('is removed when cleared, and a fresh channel has none', () {
      final mapped = Conversation.mainChannel(agentName: 'Agent')
          .withRuntimeSession('hermes', 'gen-1');

      final cleared = mapped.withRuntimeSession('hermes', null);

      expect(cleared.runtimeSessionId('hermes'), isNull);
      expect(
        cleared.metadata.containsKey(Conversation.runtimeSessionsKey),
        isFalse,
      );
      expect(
        Conversation.mainChannel(agentName: 'Agent').runtimeSessionId('hermes'),
        isNull,
      );
    });
  });
}
