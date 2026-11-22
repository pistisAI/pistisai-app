import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pistisai/database/drift_local_brain.dart' show LocalBrain;
import 'package:pistisai/models/avatar/personality_models.dart';
import 'package:pistisai/services/avatar/avatar_state_service.dart';
import 'package:pistisai/services/avatar/evolution_tracker.dart';
import 'package:pistisai/services/avatar/markdown_sync_service.dart';
import 'package:pistisai/services/avatar/personality_engine.dart';

void main() {
  late LocalBrain db;
  late AvatarStateService avatar;
  late Directory tmp;
  late List<ExtendedAvatarProfile> published;

  setUp(() async {
    db = LocalBrain.withExecutor(NativeDatabase.memory());
    tmp = await Directory.systemTemp.createTemp('avatar-publish-');
    avatar = AvatarStateService(
      database: db,
      personalityEngine: PersonalityEngine(database: db),
      evolutionTracker: EvolutionTracker(database: db),
      markdownSyncService:
          MarkdownSyncService(database: db, markdownPath: tmp.path),
    );
    published = [];
    avatar.onPersonalityChanged = published.add;
  });

  tearDown(() async {
    await db.close();
    if (await tmp.exists()) await tmp.delete(recursive: true);
  });

  test('publishes once at load, and not again when nothing changed', () async {
    await avatar.loadProfile();
    await avatar.loadProfile();
    expect(published, hasLength(1));
    expect(published.single.evolutionStage, 'curious_explorer');
  });

  test('publishes again when a trait or the name changes', () async {
    await avatar.loadProfile();
    await avatar.updateTraits(PersonalityTraits(
      formality: 0.1,
      humor: 0.9,
      enthusiasm: 0.5,
      empathy: 0.5,
    ));
    await avatar.updateAgentName('Nova');

    expect(published, hasLength(3));
    expect(published[1].traits.humor, 0.9);
    expect(published[2].agentName, 'Nova');
  });

  test('republishPersonality sends the current profile again', () async {
    await avatar.loadProfile();
    avatar.republishPersonality();
    expect(published, hasLength(2));
  });
}
