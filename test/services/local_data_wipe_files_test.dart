// Issue #1011: the local data wipe must also remove the plain files the app
// writes outside its encrypted stores, and a wiped chat must not be imported
// again from the agent runtime's transcript.
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pistisai/database/drift_local_brain.dart' show LocalBrain;
import 'package:pistisai/models/message.dart';
import 'package:pistisai/services/app_temp_files.dart';
import 'package:pistisai/services/avatar/markdown_sync_service.dart';
import 'package:pistisai/services/hermes/transcript_import_floor.dart';
import 'package:pistisai/services/local_agent_data_portability_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late Directory sandbox;
  late Directory skillDir;
  late Directory tempBase;
  late LocalBrain brain;
  late MarkdownSyncService markdown;

  setUp(() async {
    sandbox = await Directory.systemTemp.createTemp('wipe_files_test_');
    skillDir = Directory('${sandbox.path}/skills/app');
    await skillDir.create(recursive: true);
    tempBase = Directory('${sandbox.path}/tmp');
    await tempBase.create();
    AppTempFiles.baseDirectoryOverride = () async => tempBase;

    brain = LocalBrain.withExecutor(NativeDatabase.memory());
    await brain.customSelect('SELECT 1').get();
    markdown = MarkdownSyncService(
      database: brain,
      markdownPath: skillDir.path,
    );
  });

  tearDown(() async {
    AppTempFiles.baseDirectoryOverride = null;
    await brain.close();
    if (await sandbox.exists()) await sandbox.delete(recursive: true);
  });

  LocalAgentDataPortabilityService wipeService() =>
      LocalAgentDataPortabilityService(
        brain: brain,
        clearPlainFiles: [markdown.clearMarkdownFiles, AppTempFiles.deleteAll],
        listRemainingPlainFiles: [
          markdown.listExistingMarkdownFiles,
          AppTempFiles.listRemaining,
        ],
      );

  group('avatar Markdown files', () {
    test('wipe deletes the Markdown files the app wrote', () async {
      await markdown.syncMemory();
      await markdown.syncContext();
      await File('${skillDir.path}/personality.md').writeAsString('x');
      expect(await markdown.listExistingMarkdownFiles(), hasLength(3));

      final result = await wipeService().deleteAllLocalAgentData();

      for (final name in MarkdownSyncService.managedFileNames) {
        expect(File('${skillDir.path}/$name').existsSync(), isFalse,
            reason: '$name must be removed by the wipe');
      }
      expect(result.verification.remainingPlainFiles, isEmpty);
      expect(result.verifiedEmpty, isTrue);
    });

    test('clearing never deletes other files in the skill folder', () async {
      await File('${skillDir.path}/memory.md').writeAsString('x');
      final skill = File('${skillDir.path}/SKILL.md');
      await skill.writeAsString('agent skill');
      final notes = File('${skillDir.path}/notes.md');
      await notes.writeAsString('not ours');

      await markdown.clearMarkdownFiles();

      expect(File('${skillDir.path}/memory.md').existsSync(), isFalse);
      expect(skill.existsSync(), isTrue);
      expect(notes.existsSync(), isTrue);
    });
  });

  group('temp captures', () {
    test('captures go into the app-owned temp folder', () async {
      final path = await AppTempFiles.newPath('capture', 'png');
      expect(path, startsWith(tempBase.path));
      expect(path, contains(AppTempFiles.folderName));
    });

    test('wipe deletes the temp capture folder and leaves other temp files',
        () async {
      final capture = File(await AppTempFiles.newPath('capture', 'png'));
      await capture.writeAsBytes([1, 2, 3]);
      final tts = File(await AppTempFiles.newPath('tts', 'wav'));
      await tts.writeAsBytes([4, 5, 6]);
      final foreign = File('${tempBase.path}/other_program.tmp');
      await foreign.writeAsString('not ours');

      final result = await wipeService().deleteAllLocalAgentData();

      expect((await AppTempFiles.directory()).existsSync(), isFalse);
      expect(foreign.existsSync(), isTrue);
      expect(result.verifiedEmpty, isTrue);
    });

    test('verification reports plain files that are still present', () async {
      final service = LocalAgentDataPortabilityService(
        brain: brain,
        listRemainingPlainFiles: [AppTempFiles.listRemaining],
      );
      final capture = File(await AppTempFiles.newPath('capture', 'png'));
      await capture.writeAsBytes([1]);

      final verification = await service.verifyDeletion();

      expect(verification.isEmpty, isFalse);
      expect(verification.remainingPlainFiles, [capture.path]);
    });

    test('a location that cannot be checked is not reported as empty',
        () async {
      final service = LocalAgentDataPortabilityService(
        brain: brain,
        listRemainingPlainFiles: [() async => throw StateError('no access')],
      );

      final verification = await service.verifyDeletion();

      expect(verification.isEmpty, isFalse);
    });
  });

  group('runtime transcript after a wipe', () {
    Message row(String id, DateTime at) => Message(
          id: id,
          content: 'text $id',
          role: MessageRole.user,
          timestamp: at,
        );

    test('messages at or before the wipe time are not imported again', () {
      final wipe = DateTime.utc(2026, 11, 20, 12);
      final harness = [
        row('old', wipe.subtract(const Duration(minutes: 5))),
        row('same', wipe),
        row('new', wipe.add(const Duration(seconds: 1))),
      ];

      final imported = transcriptAfterImportFloor(harness, wipe);

      expect(imported.map((m) => m.id), ['new']);
    });

    test('without a recorded wipe the whole transcript is imported', () {
      final harness = [row('a', DateTime.utc(2026, 1, 1))];
      expect(transcriptAfterImportFloor(harness, null), harness);
    });

    test('the wipe time survives an app restart', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      expect(await TranscriptImportFloorStore.read(), isNull);

      final wipe = DateTime.utc(2026, 11, 20, 12, 30);
      expect(await TranscriptImportFloorStore.write(wipe), isTrue);

      final restored = await TranscriptImportFloorStore.read();
      expect(restored, isNotNull);
      expect(restored!.isAtSameMomentAs(wipe), isTrue);
    });
  });
}
