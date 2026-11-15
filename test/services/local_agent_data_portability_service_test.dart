import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pistisai/database/drift_local_brain.dart';
import 'package:pistisai/services/local_agent_data_portability_service.dart';

void main() {
  late LocalBrain brain;
  late LocalAgentDataPortabilityService service;

  setUp(() async {
    brain = LocalBrain.withExecutor(NativeDatabase.memory());
    // Force schema creation.
    await brain.customSelect('SELECT 1').get();
    service = LocalAgentDataPortabilityService(brain: brain);
  });

  tearDown(() async {
    await brain.close();
  });

  group('LocalAgentDataPortabilityService', () {
    test('exportAllToJson includes format metadata and seeded table rows',
        () async {
      final jsonString = await service.exportAllToJson();
      final decoded = jsonDecode(jsonString) as Map<String, dynamic>;

      expect(decoded['version'], LocalAgentDataPortabilityService.exportVersion);
      expect(decoded['format'], LocalAgentDataPortabilityService.exportFormat);
      expect(decoded['exportedAt'], isA<String>());
      expect(decoded['tables'], isA<Map>());
      expect(decoded['rowCounts'], isA<Map>());

      final tables = decoded['tables'] as Map<String, dynamic>;
      expect(tables.containsKey('conversations'), isTrue);
      expect(tables.containsKey('messages'), isTrue);
      expect(tables.containsKey('agent_identities'), isTrue);
    });

    test('exportAllToJson includes inserted conversation and message rows',
        () async {
      await brain.into(brain.users).insert(
            UsersCompanion.insert(id: 'user-1', name: const Value('Test User')),
          );
      await brain.into(brain.conversations).insert(
            ConversationsCompanion.insert(
              id: 'conv-1',
              userId: 'user-1',
              title: 'Hello',
              model: 'hermes',
            ),
          );
      await brain.into(brain.messages).insert(
            MessagesCompanion.insert(
              conversationId: 'conv-1',
              role: 'user',
              content: 'secret note',
            ),
          );

      final decoded =
          jsonDecode(await service.exportAllToJson()) as Map<String, dynamic>;
      final tables = decoded['tables'] as Map<String, dynamic>;
      final conversations = tables['conversations'] as List<dynamic>;
      final messages = tables['messages'] as List<dynamic>;

      expect(conversations, hasLength(1));
      expect((conversations.first as Map)['title'], 'Hello');
      expect(messages, hasLength(1));
      expect((messages.first as Map)['content'], 'secret note');
      expect((decoded['rowCounts'] as Map)['conversations'], 1);
      expect((decoded['rowCounts'] as Map)['messages'], 1);
    });

    test('deleteAllLocalAgentData removes user content and verifies empty',
        () async {
      await brain.into(brain.users).insert(
            UsersCompanion.insert(id: 'user-1'),
          );
      await brain.into(brain.conversations).insert(
            ConversationsCompanion.insert(
              id: 'conv-1',
              userId: 'user-1',
              title: 'To delete',
              model: 'hermes',
            ),
          );
      await brain.into(brain.messages).insert(
            MessagesCompanion.insert(
              conversationId: 'conv-1',
              role: 'user',
              content: 'gone soon',
            ),
          );

      final result = await service.deleteAllLocalAgentData();

      expect(result.verifiedEmpty, isTrue);
      expect(result.deletedRowCounts['conversations'], greaterThanOrEqualTo(1));
      expect(result.deletedRowCounts['messages'], greaterThanOrEqualTo(1));
      expect(result.duration.inMilliseconds, greaterThanOrEqualTo(0));

      final verification = await service.verifyDeletion();
      expect(verification.isEmpty, isTrue);
      expect(verification.remainingUserContentCounts['conversations'], 0);
      expect(verification.remainingUserContentCounts['messages'], 0);

      final conversations = await brain.select(brain.conversations).get();
      final messages = await brain.select(brain.messages).get();
      expect(conversations, isEmpty);
      expect(messages, isEmpty);
    });

    test('generateExportFilename uses json extension and brand prefix', () {
      final name = service.generateExportFilename();
      expect(name.endsWith('.json'), isTrue);
      expect(name.contains('local-agent-data'), isTrue);
    });
  });
}
