import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pistisai/database/drift_local_brain.dart';
import 'package:pistisai/services/agent_action_audit_service.dart';
import 'package:pistisai/services/local_agent_data_portability_service.dart';

void main() {
  late LocalBrain brain;
  late AgentActionAuditService audit;
  late LocalAgentDataPortabilityService service;
  late List<String> conversationFilesOnDisk;
  var chatResetCount = 0;

  setUp(() async {
    brain = LocalBrain.withExecutor(NativeDatabase.memory());
    // Force schema creation.
    await brain.customSelect('SELECT 1').get();
    audit = AgentActionAuditService(database: brain);
    conversationFilesOnDisk = <String>[];
    chatResetCount = 0;
    service = LocalAgentDataPortabilityService(
      brain: brain,
      audit: audit,
      clearConversations: () async {
        conversationFilesOnDisk.clear();
      },
      listRemainingConversationFiles: () async =>
          List<String>.from(conversationFilesOnDisk),
      resetChatState: () async {
        chatResetCount++;
      },
    );
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
      await audit.record(
        action: 'tool.read_file',
        dataTouched: 'path:/tmp/example.txt',
        authorizationStatus: AgentAuditAuthorization.authorized,
        outcome: AgentAuditOutcome.success,
      );
      conversationFilesOnDisk.add('/tmp/conversations.json.enc');

      final result = await service.deleteAllLocalAgentData();

      expect(result.verifiedEmpty, isTrue);
      expect(result.conversationsCleared, isTrue);
      expect(result.deletedRowCounts['conversations'], greaterThanOrEqualTo(1));
      expect(result.deletedRowCounts['messages'], greaterThanOrEqualTo(1));
      expect(result.deletedRowCounts['agent_action_audit_entries'],
          greaterThanOrEqualTo(1));
      expect(result.duration.inMilliseconds, greaterThanOrEqualTo(0));
      expect(chatResetCount, 1);

      final verification = await service.verifyDeletion();
      expect(verification.isEmpty, isTrue);
      expect(verification.remainingUserContentCounts['conversations'], 0);
      expect(verification.remainingUserContentCounts['messages'], 0);
      expect(
        verification.remainingUserContentCounts['agent_action_audit_entries'],
        0,
      );
      expect(verification.remainingConversationFiles, isEmpty);

      final conversations = await brain.select(brain.conversations).get();
      final messages = await brain.select(brain.messages).get();
      expect(conversations, isEmpty);
      expect(messages, isEmpty);

      final audits = await audit.list(limit: 10);
      expect(audits, hasLength(1));
      expect(audits.single.action,
          LocalAgentDataPortabilityService.wipeAuditAction);
    });

    test('verifyDeletion fails when conversation files remain', () async {
      conversationFilesOnDisk.add('/legacy/chat/conversations.json.enc');

      final verification = await service.verifyDeletion();
      expect(verification.isEmpty, isFalse);
      expect(
        verification.remainingConversationFiles,
        ['/legacy/chat/conversations.json.enc'],
      );
    });

    test('generateExportFilename uses json extension and brand prefix', () {
      final name = service.generateExportFilename();
      expect(name.endsWith('.json'), isTrue);
      expect(name.contains('local-agent-data'), isTrue);
    });
  });
}
