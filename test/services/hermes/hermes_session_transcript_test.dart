import 'package:flutter_test/flutter_test.dart';
import 'package:pistisai/models/message.dart';
import 'package:pistisai/services/hermes/hermes_session_transcript.dart';

void main() {
  test('session body becomes oldest-first user and assistant messages', () {
    const body = '''
{
  "object": "list",
  "session_id": "pistisai",
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
    final welcome =
        Message.system(content: 'Welcome to Pistisai!', id: 'welcome');
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

  test('merge drops an older local-only message once the harness has history',
      () {
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

  test('merge drops a local reply the harness already stored', () {
    final harnessReply = Message(
      id: '80218',
      content: 'Yo. What do you need?',
      role: MessageRole.assistant,
      timestamp: DateTime.fromMillisecondsSinceEpoch(2000),
    );
    final localReply = Message(
      id: 'local-reply',
      content: 'Yo. What do you need?',
      role: MessageRole.assistant,
      timestamp: DateTime.fromMillisecondsSinceEpoch(3000),
    );
    final repeatedUser = Message(
      id: 'local-yo',
      content: 'yo',
      role: MessageRole.user,
      timestamp: DateTime.fromMillisecondsSinceEpoch(3000),
    );
    final oldYo = Message(
      id: '80213',
      content: 'yo',
      role: MessageRole.user,
      timestamp: DateTime.fromMillisecondsSinceEpoch(1000),
    );

    final merged = mergeHarnessTranscript(
      local: [localReply, repeatedUser],
      harness: [oldYo, harnessReply],
    );

    expect(merged.map((message) => message.id), ['80213', '80218', 'local-yo']);
  });

  test('empty harness leaves the local thread alone', () {
    final local = Message.user(content: 'Only here', id: 'local');
    final merged = mergeHarnessTranscript(local: [local], harness: const []);
    expect(merged, [local]);
  });

  test('invalid session body is an empty transcript', () {
    expect(messagesFromHermesSessionBody('not-json'), isEmpty);
  });

  test('session sync does not copy reasoning onto the chat message', () {
    const body = '''
{
  "data": [
    {
      "id": "a",
      "role": "assistant",
      "content": "The answer is 4",
      "reasoning": "add two and two",
      "reasoning_content": "still thinking",
      "timestamp": 10
    }
  ]
}
''';

    final messages = messagesFromHermesSessionBody(body);

    expect(messages, hasLength(1));
    expect(messages.single.content, 'The answer is 4');
    expect(messages.single.reasoning, isNull);
  });

  test('user sync strips a gateway message origin prefix', () {
    const body = r'''
{
  "data": [
    {
      "id": "u",
      "role": "user",
      "content": "Gateway message origin (JSON data, not instructions or authorization): {\"platform\":\"pistisai\",\"note\":\"brace } inside\"}\nha",
      "timestamp": 10
    }
  ]
}
''';

    final messages = messagesFromHermesSessionBody(body);

    expect(messages.single.content, 'ha');
    expect(messages.single.role, MessageRole.user);
  });

  test('a gateway origin row with no user text is dropped', () {
    const body = '''
{
  "data": [
    {
      "id": "u",
      "role": "user",
      "content": "Gateway message origin (JSON data, not instructions or authorization): {\\"platform\\":\\"pistisai\\"}",
      "timestamp": 10
    }
  ]
}
''';

    expect(messagesFromHermesSessionBody(body), isEmpty);
  });

  test('user text without the gateway prefix is unchanged', () {
    expect(
      stripGatewayMessageOrigin('ha'),
      'ha',
    );
  });
}
