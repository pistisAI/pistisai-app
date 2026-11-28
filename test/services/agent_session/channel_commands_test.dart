import 'package:flutter_test/flutter_test.dart';
import 'package:pistisai/models/conversation.dart';
import 'package:pistisai/models/message.dart';
import 'package:pistisai/services/agent_session/channel.dart';
import 'package:pistisai/services/agent_session/channel_commands.dart';
import 'package:pistisai/services/agent_session/harness_event.dart';
import 'package:pistisai/services/agent_session/hermes_owned_session.dart';
import 'package:pistisai/services/agent_session/hub_channel_view.dart';
import 'package:pistisai/services/agent_session/legacy_history_import.dart';

void main() {
  test('/new and /reset are channel commands', () {
    expect(channelCommandFor('/new'), ChannelCommand.newChannel);
    expect(channelCommandFor('  /reset '), ChannelCommand.resetChannel);
    expect(channelCommandFor('hello'), ChannelCommand.none);
    final topic = newTopicChannel(model: 'hermes-agent');
    expect(topic.channel.kind, ChannelKind.topic);
    expect(topic.channelId, topic.id);
    expect(topic.channelId, isNot(Conversation.pistisaiChannelId));
  });

  test('legacy import honours a wipe and runs once', () {
    final old = Message.user(content: 'old', id: 'old');
    final kept = Message.user(
      content: 'new',
      id: 'new',
    );
    final floor = DateTime.now().toUtc().add(const Duration(seconds: 1));
    final before = Message(
      id: 'before',
      content: 'wiped',
      role: MessageRole.user,
      timestamp: floor.subtract(const Duration(seconds: 2)),
    );
    final after = Message(
      id: 'after',
      content: 'kept',
      role: MessageRole.user,
      timestamp: floor.add(const Duration(seconds: 2)),
    );
    expect(
      legacyHistoryToImport(
        alreadyImported: true,
        transcript: [old, kept],
        floor: null,
      ),
      isEmpty,
    );
    expect(
      legacyHistoryToImport(
        alreadyImported: false,
        transcript: null,
        floor: null,
      ),
      isNull,
    );
    final selected = legacyHistoryToImport(
      alreadyImported: false,
      transcript: [before, after],
      floor: floor,
    );
    expect(selected!.map((message) => message.id), ['after']);
  });

  test('hub channel JSON omits runtime session ids', () {
    final conversation = Conversation.mainChannel()
        .withRuntimeSession('hermes', 'api_secret_session')
        .addMessage(Message.user(content: 'hi', id: 'm1'));
    final summary = hubChannelSummary(conversation);
    expect(summary.containsKey('runtimeSessions'), isFalse);
    expect(summary['id'], Conversation.pistisaiChannelId);
    final detail = hubChannelDetail(conversation);
    final encoded = detail.toString();
    expect(encoded.contains('api_secret_session'), isFalse);
    expect((detail['messages'] as List).single['content'], 'hi');
  });

  test('SSE parser skips keepalives and maps deltas and tools', () {
    final parser = HermesSseParser();
    final events = parser.add(
      ': keepalive\n'
      '\n'
      'event: assistant.delta\n'
      'data: {"message_id":"m","delta":"Hel"}\n'
      '\n'
      'event: assistant.delta\n'
      'data: {"message_id":"m","delta":"lo"}\n'
      '\n'
      'event: tool.started\n'
      'data: {"message_id":"m","tool_name":"read_file","seq":3}\n'
      '\n'
      'event: assistant.completed\n'
      'data: {"message_id":"m","content":"Hello"}\n'
      '\n',
    );
    expect(events.map((event) => event.name), [
      'assistant.delta',
      'assistant.delta',
      'tool.started',
      'assistant.completed',
    ]);
    final harness = [
      for (final event in events)
        harnessEventForSse(channelId: 'pistisai', event: event),
    ];
    expect(harness[0], isA<HarnessDelta>());
    expect((harness[0] as HarnessDelta).text, 'Hel');
    expect((harness[2] as HarnessToolStarted).toolName, 'read_file');
    expect(
      (harness[3] as HarnessMessageCompleted).message.content,
      'Hello',
    );
  });
}
