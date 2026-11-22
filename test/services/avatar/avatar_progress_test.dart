import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pistisai/database/drift_local_brain.dart' show LocalBrain;
import 'package:pistisai/models/conversation.dart';
import 'package:pistisai/models/message.dart';
import 'package:pistisai/services/avatar/avatar_state_service.dart';
import 'package:pistisai/services/avatar/evolution_tracker.dart';
import 'package:pistisai/services/avatar/markdown_sync_service.dart';
import 'package:pistisai/services/avatar/personality_engine.dart';

Message _msg(String id, MessageRole role, DateTime at, String content) =>
    Message(id: id, content: content, role: role, timestamp: at);

Conversation _conversation(List<Message> messages) {
  var c = Conversation.mainChannel(model: 'hermes-agent');
  for (final m in messages) {
    c = c.addMessage(m);
  }
  return c;
}

void main() {
  late LocalBrain db;
  late AvatarStateService avatar;
  late Directory tmp;
  final t0 = DateTime(2026, 11, 20, 9);

  setUp(() async {
    db = LocalBrain.withExecutor(NativeDatabase.memory());
    tmp = await Directory.systemTemp.createTemp('avatar-progress-');
    avatar = AvatarStateService(
      database: db,
      personalityEngine: PersonalityEngine(database: db),
      evolutionTracker: EvolutionTracker(database: db),
      markdownSyncService:
          MarkdownSyncService(database: db, markdownPath: tmp.path),
    );
    await avatar.loadProfile();
  });

  tearDown(() async {
    await db.close();
    if (await tmp.exists()) await tmp.delete(recursive: true);
  });

  List<Message> exchange(String tag, DateTime at) => [
        _msg('u$tag', MessageRole.user, at, 'How do I test an API?'),
        _msg('a$tag', MessageRole.assistant,
            at.add(const Duration(seconds: 20)), 'Use an integration test.'),
      ];

  test('nothing is recorded before the agent has answered', () async {
    await avatar.recordExchange(
        _conversation([_msg('u1', MessageRole.user, t0, 'hello')]));
    expect(avatar.conversationCount, 0);
    expect(await db.getAllDepthMetrics(), isEmpty);
  });

  test('a completed exchange counts as the first conversation', () async {
    await avatar.recordExchange(_conversation(exchange('1', t0)));

    expect(avatar.conversationCount, 1);
    expect(await db.getAllDepthMetrics(), hasLength(1));
    final unlocked = await db.getUnlockedAchievements();
    expect(unlocked.map((a) => a.achievementId), contains('first_chat'));
  });

  test('more messages in the same session do not add a conversation', () async {
    final first = exchange('1', t0);
    final second = exchange('2', t0.add(const Duration(minutes: 5)));
    await avatar.recordExchange(_conversation(first));
    await avatar.recordExchange(_conversation([...first, ...second]));

    expect(avatar.conversationCount, 1);
    expect(await db.getAllDepthMetrics(), hasLength(1));
  });

  test('a pause of 30 minutes or more starts a new conversation', () async {
    final first = exchange('1', t0);
    final later = exchange('2', t0.add(const Duration(hours: 2)));
    await avatar.recordExchange(_conversation(first));
    await avatar.recordExchange(_conversation([...first, ...later]));

    expect(avatar.conversationCount, 2);
    expect(await db.getAllDepthMetrics(), hasLength(2));
  });

  test('recording the same reply twice changes nothing', () async {
    final c = _conversation(exchange('1', t0));
    await avatar.recordExchange(c);
    await avatar.recordExchange(c);
    expect(avatar.conversationCount, 1);
  });

  test('five sessions unlock the 5-conversation achievement', () async {
    var all = <Message>[];
    for (var i = 0; i < 5; i++) {
      all = [...all, ...exchange('$i', t0.add(Duration(hours: i * 2)))];
      await avatar.recordExchange(_conversation(all));
    }
    expect(avatar.conversationCount, 5);
    final unlocked = await db.getUnlockedAchievements();
    expect(unlocked.map((a) => a.achievementId),
        containsAll(['first_chat', 'deep_conversations_5']));
  });

  test('earnedAchievements has nothing for a new avatar', () {
    expect(
      AvatarStateService.earnedAchievements(
        conversationCount: 0,
        averageNovelty: 0,
        evolutionStage: 'curious_explorer',
      ),
      isEmpty,
    );
  });

  test('a data wipe leaves foreign keys as they were, so tracking still works',
      () async {
    await db.deleteAllAgentData();
    await avatar.recordExchange(_conversation(exchange('1', t0)));
    expect(await db.getAllDepthMetrics(), hasLength(1));
  });
}
