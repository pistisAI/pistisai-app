import 'package:flutter_test/flutter_test.dart';
import 'package:pistisai/models/message.dart';
import 'package:pistisai/services/hermes/hermes_session_transcript.dart';

void main() {
  test('session body becomes oldest-first user and assistant messages', () {
    const body = '''
{
  "object": "list",
  "session_id": "main-channel",
  "data": [
    {
      "id": "b",
      "role": "assistant",
      "content": "Second",
      "timestamp": 20
    },
    {
      "id": "a",
      "role": "user",
      "content": [{"type": "text", "text": "First"}],
      "timestamp": 10
    },
    {
      "id": "hidden",
      "role": "assistant",
      "content": "skip",
      "display_kind": "hidden",
      "timestamp": 15
    },
    {
      "id": "tool",
      "role": "tool",
      "content": "skip tool",
      "timestamp": 16
    }
  ]
}
''';

    final messages = messagesFromHermesSessionBody(body);

    expect(messages.map((message) => message.id), ['a', 'b']);
    expect(messages.first.role, MessageRole.user);
    expect(messages.first.content, 'First');
    expect(messages.last.role, MessageRole.assistant);
    expect(messages.last.content, 'Second');
  });

  test('merge keeps a just-sent local message and drops the local welcome', () {
    final welcome = Message.system(content: 'Welcome to Pistisai!', id: 'welcome');
    final pending = Message.user(content: 'Still sending', id: 'local');
    final shared = Message(
      id: 'a',
      content: 'Already on the harness',
      role: MessageRole.user,
      timestamp: DateTime.fromMillisecondsSinceEpoch(1000),
    );

    final merged = mergeHarnessTranscript(
      local: [welcome, pending],
      harness: [shared],
    );

    expect(merged.map((message) => message.id), ['a', 'local']);
  });

  test('merge drops an older local-only message once the harness has history', () {
    final oldLocal = Message(
      id: 'old',
      content: 'Only on this device',
      role: MessageRole.user,
      timestamp: DateTime.fromMillisecondsSinceEpoch(500),
    );
    final shared = Message(
      id: 'a',
      content: 'Shared',
      role: MessageRole.assistant,
      timestamp: DateTime.fromMillisecondsSinceEpoch(2000),
    );

    final merged = mergeHarnessTranscript(
      local: [oldLocal],
      harness: [shared],
    );

    expect(merged.map((message) => message.id), ['a']);
  });

  test('empty harness leaves the local thread alone', () {
    final local = Message.user(content: 'Only here', id: 'local');
    final merged = mergeHarnessTranscript(local: [local], harness: const []);
    expect(merged, [local]);
  });

  test('invalid session body is an empty transcript', () {
    expect(messagesFromHermesSessionBody('not-json'), isEmpty);
  });

  test('merge deduplicates a just-sent local message by content+role+time', () {
    // Simulate a user message sent locally, then stored on the harness
    // with a different server-generated ID.
    final localUser = Message.user(
      content: 'yo',
      id: 'local_123',
      metadata: const {},
    );
    final harnessUser = Message(
      id: 'hermes_abc',
      content: 'yo',
      role: MessageRole.user,
      timestamp: localUser.timestamp.add(const Duration(seconds: 1)),
    );
    final harnessAssistant = Message(
      id: 'hermes_def',
      content: 'Yo. What\'s up?',
      role: MessageRole.assistant,
      timestamp: harnessUser.timestamp.add(const Duration(seconds: 2)),
    );

    final merged = mergeHarnessTranscript(
      local: [localUser],
      harness: [harnessUser, harnessAssistant],
    );

    // The local duplicate should be dropped; only the harness rows remain.
    expect(merged.map((message) => message.id), ['hermes_abc', 'hermes_def']);
    expect(merged.map((message) => message.role), [MessageRole.user, MessageRole.assistant]);
  });
}
