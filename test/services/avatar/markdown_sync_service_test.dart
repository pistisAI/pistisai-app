import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pistisai/database/drift_local_brain.dart';
import 'package:pistisai/models/avatar/personality_models.dart';
import 'package:pistisai/services/avatar/markdown_sync_service.dart';

/// A fake [LocalBrain] that returns canned responses for testing.
/// Avoids the build_runner dependency by implementing the interface manually.
class FakeLocalBrain implements LocalBrain {
  List<AvatarMemoryEntry> _memoryEntries = [];
  AvatarPersonalityProfile? _profile;
  List<ConversationDepthMetric> _depthMetrics = [];
  List<EvolutionHistory> _evolutionHistory = [];

  void setMemoryEntries(List<AvatarMemoryEntry> entries) {
    _memoryEntries = entries;
  }

  void setProfile(AvatarPersonalityProfile profile) {
    _profile = profile;
  }

  void setDepthMetrics(List<ConversationDepthMetric> metrics) {
    _depthMetrics = metrics;
  }

  void setEvolutionHistory(List<EvolutionHistory> history) {
    _evolutionHistory = history;
  }

  @override
  Future<List<AvatarMemoryEntry>> getAllAvatarMemoryEntries() async =>
      _memoryEntries;

  @override
  Future<AvatarPersonalityProfile> getAvatarProfile() async =>
      _profile ??
      AvatarPersonalityProfile(
        id: 'default',
        agentName: 'TestBot',
        personalityTraits: '{}',
        evolutionStage: 'base',
        conversationCount: 0,
        depthScore: 0.0,
        createdAt: DateTime.now().millisecondsSinceEpoch,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      );

  @override
  Future<List<ConversationDepthMetric>> getDepthMetrics() async =>
      _depthMetrics;

  @override
  Future<List<EvolutionHistory>> getEvolutionHistory() async =>
      _evolutionHistory;

  // Unused methods — provide no-op implementations
  @override
  Future<void> addConversationDepthMetrics(
      ConversationDepthMetricsCompanion companion) async {}

  @override
  Future<void> close() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Helper to create a temporary directory for test markdown files.
Directory _createTempDir() {
  final dir = Directory.systemTemp.createTempSync('markdown_sync_test_');
  addTearDown(() {
    if (dir.existsSync()) {
      dir.deleteSync(recursive: true);
    }
  });
  return dir;
}

/// Helper to create a mock AvatarMemoryEntry.
AvatarMemoryEntry _memoryEntry({
  required String key,
  required String type,
  required String value,
  required int importance,
  List<String>? tags,
}) {
  final now = DateTime.now();
  return AvatarMemoryEntry(
    id: importance, // Use importance as id for uniqueness
    avatarId: 'default',
    memoryType: type,
    memoryKey: key,
    memoryValue: value,
    importance: importance,
    lastAccessed: now,
    timestamp: now,
    createdAt: now,
    tags: tags?.join(','),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeLocalBrain fakeDb;
  late Directory tempDir;

  setUp(() {
    fakeDb = FakeLocalBrain();
    tempDir = _createTempDir();
  });

  group('MarkdownSyncService', () {
    group('constructor', () {
      test('creates service with database and path', () {
        final service = MarkdownSyncService(
          database: fakeDb,
          markdownPath: tempDir.path,
        );
        expect(service, isA<MarkdownSyncService>());
      });
    });

    group('syncPersonality', () {
      test('writes personality markdown file', () async {
        final profile = ExtendedAvatarProfile(
          agentName: 'TestBot',
          traits: PersonalityTraits(
            formality: 0.7,
            humor: 0.4,
            enthusiasm: 0.8,
            empathy: 0.9,
          ),
          evolutionStage: 'curious_explorer',
          conversationCount: 42,
          depthScore: 0.75,
        );

        fakeDb.setEvolutionHistory([]);
        fakeDb.setDepthMetrics([]);

        final service = MarkdownSyncService(
          database: fakeDb,
          markdownPath: tempDir.path,
        );

        await service.syncPersonality(profile);

        // Verify the file was created
        final file = File('${tempDir.path}/personality.md');
        expect(await file.exists(), isTrue);

        final content = await file.readAsString();

        // Verify frontmatter
        expect(content, contains('agent_name: TestBot'));
        expect(content, contains('formality: 0.7'));
        expect(content, contains('humor: 0.4'));
        expect(content, contains('enthusiasm: 0.8'));
        expect(content, contains('empathy: 0.9'));
        expect(content, contains('evolution_stage: curious_explorer'));
        expect(content, contains('conversation_count: 42'));
        expect(content, contains('depth_score: 0.75'));

        // Verify body
        expect(content, contains('# TestBot Personality'));
        expect(content, contains('Formality: 70%'));
        expect(content, contains('Humor: 40%'));
        expect(content, contains('Enthusiasm: 80%'));
        expect(content, contains('Empathy: 90%'));
        expect(content, contains('## Evolution Stage: curious_explorer'));
        expect(content, contains('Conversations: 42'));
        expect(content, contains('Depth Score: 0.75'));
      });

      test('includes evolution history when available', () async {
        final profile = ExtendedAvatarProfile(
          agentName: 'TestBot',
          traits: PersonalityTraits.defaultTraits,
          evolutionStage: 'wise_mentor',
          conversationCount: 100,
          depthScore: 0.9,
        );

        fakeDb.setEvolutionHistory([
          EvolutionHistory(
            id: '1',
            avatarId: 'default',
            fromStage: 'base',
            toStage: 'curious_explorer',
            triggerReason: 'Reached depth threshold',
            confirmedBy: 'system',
            triggeredAt: DateTime.now().millisecondsSinceEpoch,
            context: 'User had 10 deep conversations',
          ),
        ]);
        fakeDb.setDepthMetrics([]);

        final service = MarkdownSyncService(
          database: fakeDb,
          markdownPath: tempDir.path,
        );

        await service.syncPersonality(profile);

        final content = await File('${tempDir.path}/personality.md')
            .readAsString();

        expect(content, contains('curious_explorer'));
        expect(content, contains('Reached depth threshold'));
        expect(content, contains('User had 10 deep conversations'));
      });

      test('handles empty evolution history gracefully', () async {
        final profile = ExtendedAvatarProfile(
          agentName: 'TestBot',
          traits: PersonalityTraits.defaultTraits,
          evolutionStage: 'base',
          conversationCount: 0,
          depthScore: 0.0,
        );

        fakeDb.setEvolutionHistory([]);
        fakeDb.setDepthMetrics([]);

        final service = MarkdownSyncService(
          database: fakeDb,
          markdownPath: tempDir.path,
        );

        await service.syncPersonality(profile);

        final content = await File('${tempDir.path}/personality.md')
            .readAsString();

        expect(content, contains('No evolution history yet.'));
      });
    });

    group('syncMemory', () {
      test('writes memory markdown file with entries', () async {
        fakeDb.setMemoryEntries([
          _memoryEntry(
            key: 'user_name',
            type: 'fact',
            value: 'John',
            importance: 90,
            tags: ['personal', 'name'],
          ),
          _memoryEntry(
            key: 'preferred_topic',
            type: 'preference',
            value: 'AI',
            importance: 60,
            tags: ['interest'],
          ),
          _memoryEntry(
            key: 'casual_greeting',
            type: 'interaction',
            value: 'Said hello',
            importance: 30,
          ),
        ]);

        final service = MarkdownSyncService(
          database: fakeDb,
          markdownPath: tempDir.path,
        );

        await service.syncMemory();

        final content = await File('${tempDir.path}/memory.md')
            .readAsString();

        // Verify frontmatter
        expect(content, contains('total_entries: 3'));

        // Verify high importance section (importance >= 80)
        expect(content, contains('## High Importance Memories'));
        expect(content, contains('user_name'));
        expect(content, contains('John'));

        // Verify medium importance section (50 <= importance < 80)
        expect(content, contains('## Medium Importance Memories'));
        expect(content, contains('preferred_topic'));

        // Verify all memories section
        expect(content, contains('## All Memories'));
        expect(content, contains('casual_greeting'));
      });

      test('writes memory file with no entries', () async {
        fakeDb.setMemoryEntries([]);

        final service = MarkdownSyncService(
          database: fakeDb,
          markdownPath: tempDir.path,
        );

        await service.syncMemory();

        final content = await File('${tempDir.path}/memory.md')
            .readAsString();

        expect(content, contains('total_entries: 0'));
        expect(content, contains('None'));
      });
    });

    group('syncContext', () {
      test('writes context markdown file with metrics', () async {
        fakeDb.setProfile(AvatarPersonalityProfile(
          id: 'default',
          agentName: 'TestBot',
          personalityTraits: '{}',
          evolutionStage: 'curious_explorer',
          conversationCount: 42,
          depthScore: 0.75,
          createdAt: 1000,
          updatedAt: 2000,
        ));

        fakeDb.setDepthMetrics([
          ConversationDepthMetric(
            id: '1',
            conversationId: 'conv1',
            complexityScore: 0.8,
            emotionalDepth: 0.7,
            noveltyScore: 0.6,
            timestamp: 1000,
          ),
          ConversationDepthMetric(
            id: '2',
            conversationId: 'conv2',
            complexityScore: 0.6,
            emotionalDepth: 0.5,
            noveltyScore: 0.4,
            timestamp: 2000,
          ),
        ]);

        fakeDb.setEvolutionHistory([]);

        final service = MarkdownSyncService(
          database: fakeDb,
          markdownPath: tempDir.path,
        );

        await service.syncContext();

        final content = await File('${tempDir.path}/context.md')
            .readAsString();

        // Verify frontmatter
        expect(content, contains('agent_name: TestBot'));
        expect(content, contains('evolution_stage: curious_explorer'));

        // Verify profile summary
        expect(content, contains('**Agent Name**'));
        expect(content, contains('TestBot'));
        expect(content, contains('**Conversations**: 42'));
        expect(content, contains('**Depth Score**: 0.75'));

        // Verify conversation patterns (averages)
        // avgComplexity = (0.8 + 0.6) / 2 = 0.70
        // avgEmotional = (0.7 + 0.5) / 2 = 0.60
        // avgNovelty = (0.6 + 0.4) / 2 = 0.50
        expect(content, contains('**Average Complexity**: 0.70'));
        expect(content, contains('**Average Emotional Depth**: 0.60'));
        expect(content, contains('**Average Novelty**: 0.50'));
        expect(content, contains('**Total Conversations Tracked**: 2'));
      });

      test('handles empty depth metrics', () async {
        fakeDb.setProfile(AvatarPersonalityProfile(
          id: 'default',
          agentName: 'TestBot',
          personalityTraits: '{}',
          evolutionStage: 'base',
          conversationCount: 0,
          depthScore: 0.0,
          createdAt: 1000,
          updatedAt: 1000,
        ));

        fakeDb.setDepthMetrics([]);
        fakeDb.setEvolutionHistory([]);

        final service = MarkdownSyncService(
          database: fakeDb,
          markdownPath: tempDir.path,
        );

        await service.syncContext();

        final content = await File('${tempDir.path}/context.md')
            .readAsString();

        // Averages should be 0.0 when no metrics
        expect(content, contains('**Average Complexity**: 0.00'));
        expect(content, contains('**Average Emotional Depth**: 0.00'));
        expect(content, contains('**Average Novelty**: 0.00'));
        expect(content, contains('**Total Conversations Tracked**: 0'));
      });
    });

    group('syncAll', () {
      test('calls all three sync methods', () async {
        final profile = ExtendedAvatarProfile(
          agentName: 'TestBot',
          traits: PersonalityTraits.defaultTraits,
          evolutionStage: 'base',
          conversationCount: 0,
          depthScore: 0.0,
        );

        fakeDb.setEvolutionHistory([]);
        fakeDb.setDepthMetrics([]);
        fakeDb.setMemoryEntries([]);
        fakeDb.setProfile(AvatarPersonalityProfile(
          id: 'default',
          agentName: 'TestBot',
          personalityTraits: '{}',
          evolutionStage: 'base',
          conversationCount: 0,
          depthScore: 0.0,
          createdAt: 1000,
          updatedAt: 1000,
        ));

        final service = MarkdownSyncService(
          database: fakeDb,
          markdownPath: tempDir.path,
        );

        await service.syncAll(profile);

        // Verify all three files were created
        expect(
            await File('${tempDir.path}/personality.md').exists(), isTrue);
        expect(await File('${tempDir.path}/memory.md').exists(), isTrue);
        expect(await File('${tempDir.path}/context.md').exists(), isTrue);
      });
    });

    group('loadPersonalityFromMarkdown', () {
      test('returns null when file does not exist', () async {
        final service = MarkdownSyncService(
          database: fakeDb,
          markdownPath: tempDir.path,
        );

        final result = await service.loadPersonalityFromMarkdown();

        expect(result, isNull);
      });

      test('loads personality from valid markdown file', () async {
        // First write a personality file
        final profile = ExtendedAvatarProfile(
          agentName: 'TestBot',
          traits: PersonalityTraits(
            formality: 0.7,
            humor: 0.4,
            enthusiasm: 0.8,
            empathy: 0.9,
          ),
          evolutionStage: 'curious_explorer',
          conversationCount: 42,
          depthScore: 0.75,
        );

        fakeDb.setEvolutionHistory([]);
        fakeDb.setDepthMetrics([]);

        final service = MarkdownSyncService(
          database: fakeDb,
          markdownPath: tempDir.path,
        );

        await service.syncPersonality(profile);

        // Now load it back
        final loaded = await service.loadPersonalityFromMarkdown();

        expect(loaded, isNotNull);
        expect(loaded!.agentName, 'TestBot');
        expect(loaded.traits.formality, 0.7);
        expect(loaded.traits.humor, 0.4);
        expect(loaded.traits.enthusiasm, 0.8);
        expect(loaded.traits.empathy, 0.9);
        expect(loaded.evolutionStage, 'curious_explorer');
        expect(loaded.conversationCount, 42);
        expect(loaded.depthScore, 0.75);
      });

      test('returns profile with defaults for malformed markdown file', () async {
        // Write a malformed file — no valid frontmatter fields
        final file = File('${tempDir.path}/personality.md');
        await file.writeAsString('This is not valid markdown frontmatter\n');

        final service = MarkdownSyncService(
          database: fakeDb,
          markdownPath: tempDir.path,
        );

        final result = await service.loadPersonalityFromMarkdown();

        // Returns a profile with defaults since the file exists and is readable
        expect(result, isNotNull);
        expect(result!.agentName, 'Agent'); // Default name
        expect(result.traits.formality, 0.5); // Default trait
        expect(result.evolutionStage, 'base'); // Default stage
      });

      test('returns profile with defaults for partially missing fields',
          () async {
        // Write a file with only some fields
        final file = File('${tempDir.path}/personality.md');
        await file.writeAsString('''---
agent_name: PartialBot
formality: 0.5
humor: 0.5
enthusiasm: 0.5
empathy: 0.5
evolution_stage: base
conversation_count: 10
depth_score: 0.5
---
''');

        final service = MarkdownSyncService(
          database: fakeDb,
          markdownPath: tempDir.path,
        );

        final result = await service.loadPersonalityFromMarkdown();

        expect(result, isNotNull);
        expect(result!.agentName, 'PartialBot');
        expect(result.traits.formality, 0.5);
        expect(result.evolutionStage, 'base');
      });
    });

    group('hasMarkdownBackup', () {
      test('returns false when no personality file exists', () async {
        final service = MarkdownSyncService(
          database: fakeDb,
          markdownPath: tempDir.path,
        );

        final hasBackup = await service.hasMarkdownBackup();

        expect(hasBackup, isFalse);
      });

      test('returns true when personality file exists', () async {
        // Create the file
        await File('${tempDir.path}/personality.md')
            .writeAsString('test');

        final service = MarkdownSyncService(
          database: fakeDb,
          markdownPath: tempDir.path,
        );

        final hasBackup = await service.hasMarkdownBackup();

        expect(hasBackup, isTrue);
      });
    });

    group('clearMarkdownFiles', () {
      test('clears all markdown files in directory', () async {
        // Create some markdown files
        await File('${tempDir.path}/personality.md')
            .writeAsString('test');
        await File('${tempDir.path}/memory.md').writeAsString('test');
        await File('${tempDir.path}/context.md').writeAsString('test');
        // Create a non-markdown file that should be preserved
        await File('${tempDir.path}/notes.txt').writeAsString('test');

        final service = MarkdownSyncService(
          database: fakeDb,
          markdownPath: tempDir.path,
        );

        await service.clearMarkdownFiles();

        expect(
            await File('${tempDir.path}/personality.md').exists(), isFalse);
        expect(await File('${tempDir.path}/memory.md').exists(), isFalse);
        expect(await File('${tempDir.path}/context.md').exists(), isFalse);
        // Non-markdown file should still exist
        expect(await File('${tempDir.path}/notes.txt').exists(), isTrue);
      });

      test('does nothing when directory does not exist', () async {
        final nonExistentDir = Directory('${tempDir.path}/nonexistent');

        final service = MarkdownSyncService(
          database: fakeDb,
          markdownPath: nonExistentDir.path,
        );

        // Should not throw
        await service.clearMarkdownFiles();
      });
    });

    group('_formatMemoryEntries', () {
      test('returns "None" for empty list', () async {
        fakeDb.setMemoryEntries([]);

        final service = MarkdownSyncService(
          database: fakeDb,
          markdownPath: tempDir.path,
        );

        await service.syncMemory();

        final content = await File('${tempDir.path}/memory.md')
            .readAsString();
        expect(content, contains('None'));
      });
    });
  });
}
