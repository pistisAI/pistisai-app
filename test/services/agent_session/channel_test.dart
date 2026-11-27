import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:pistisai/services/agent_session/channel.dart';
import 'package:pistisai/services/agent_session/harness_adapter.dart';
import 'package:pistisai/services/agent_session/harness_event.dart';

void main() {
  group('ConversationChannel', () {
    test('round-trips through JSON text', () {
      final channel = ConversationChannel(
        id: 'ch-1',
        kind: ChannelKind.topic,
        title: 'Project notes',
        createdAt: DateTime.utc(2026, 11, 27, 9, 30),
      );
      final text = jsonEncode(channel.toJson());
      final back = ConversationChannel.fromJson(
        (jsonDecode(text) as Map).cast<String, Object?>(),
      );
      expect(back, channel);
      expect(back.kind, ChannelKind.topic);
    });

    test('stores createdAt in UTC', () {
      final local = DateTime(2026, 11, 27, 9, 30);
      final channel = ConversationChannel(
        id: 'ch-1',
        kind: ChannelKind.direct,
        title: 'Direct',
        createdAt: local,
      );
      expect(channel.createdAt.isUtc, isTrue);
      expect(channel.createdAt, local.toUtc());
    });

    test('copyWith keeps the identity', () {
      final channel = ConversationChannel(
        id: 'ch-1',
        kind: ChannelKind.direct,
        title: 'Old',
        createdAt: DateTime.utc(2026),
      );
      final renamed = channel.copyWith(title: 'New');
      expect(renamed.id, channel.id);
      expect(renamed.createdAt, channel.createdAt);
      expect(renamed.title, 'New');
    });

    test('rejects an empty id', () {
      expect(
        () => ConversationChannel(
          id: ' ',
          kind: ChannelKind.direct,
          title: 't',
          createdAt: DateTime.utc(2026),
        ),
        throwsArgumentError,
      );
    });

    test('fromJson refuses bad input instead of inventing values', () {
      final good = <String, Object?>{
        'id': 'ch-1',
        'kind': 'direct',
        'title': 't',
        'createdAt': '2026-11-27T00:00:00.000Z',
      };
      for (final broken in <Map<String, Object?>>[
        {...good}..remove('id'),
        {...good, 'kind': 'group'},
        {...good, 'title': 3},
        {...good, 'createdAt': 'yesterday'},
      ]) {
        expect(
          () => ConversationChannel.fromJson(broken),
          throwsFormatException,
          reason: '$broken',
        );
      }
    });
  });

  group('HarnessCapabilities', () {
    test('every capability is off unless an adapter turns it on', () {
      const caps = HarnessCapabilities();
      expect(caps.streaming, isFalse);
      expect(caps.agentEvents, isFalse);
      expect(caps.proactive, isFalse);
    });
  });

  group('HarnessEvent', () {
    test('is exhaustively switchable', () {
      final message = HarnessMessage(
        id: 'm1',
        role: HarnessRole.assistant,
        content: 'hi',
        createdAt: DateTime.utc(2026),
      );
      final events = <HarnessEvent>[
        const HarnessDelta(channelId: 'c', messageId: 'm1', text: 'h'),
        HarnessMessageCompleted(channelId: 'c', message: message),
        const HarnessToolStarted(
            channelId: 'c', toolCallId: 't1', toolName: 'search'),
        const HarnessToolFinished(
            channelId: 'c', toolCallId: 't1', toolName: 'search'),
        const HarnessError(channelId: 'c', message: 'down'),
      ];
      final labels = events
          .map((e) => switch (e) {
                HarnessDelta() => 'delta',
                HarnessMessageCompleted() => 'completed',
                HarnessToolStarted() => 'toolStarted',
                HarnessToolFinished(:final failed) =>
                  failed ? 'toolFailed' : 'toolFinished',
                HarnessError() => 'error',
              })
          .toList();
      expect(labels,
          ['delta', 'completed', 'toolStarted', 'toolFinished', 'error']);
      expect(events.every((e) => e.channelId == 'c'), isTrue);
    });
  });
}
