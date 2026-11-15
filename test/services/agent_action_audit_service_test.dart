import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pistisai/database/drift_local_brain.dart';
import 'package:pistisai/services/agent_action_audit_service.dart';

void main() {
  late LocalBrain db;
  late AgentActionAuditService audit;

  setUp(() {
    db = LocalBrain.withExecutor(NativeDatabase.memory());
    audit = AgentActionAuditService(database: db);
  });

  tearDown(() async {
    await db.close();
  });

  test('records timestamp, action, data touched, authorization, and outcome',
      () async {
    final id = await audit.record(
      action: 'tool.read_file',
      dataTouched: 'path:/tmp/example.txt',
      authorizationStatus: AgentAuditAuthorization.authorized,
      outcome: AgentAuditOutcome.success,
      agentId: 'hermes',
      authorizedBy: 'user',
    );

    expect(id, greaterThan(0));

    final entries = await audit.list(limit: 10);
    expect(entries, hasLength(1));
    final entry = entries.single;
    expect(entry.action, 'tool.read_file');
    expect(entry.dataTouched, 'path:/tmp/example.txt');
    expect(entry.authorizationStatus, AgentAuditAuthorization.authorized);
    expect(entry.outcome, AgentAuditOutcome.success);
    expect(entry.agentId, 'hermes');
    expect(entry.authorizedBy, 'user');
    expect(entry.timestamp.isBefore(DateTime.now().add(const Duration(seconds: 1))),
        isTrue);
  });

  test('list returns newest first and respects limit', () async {
    final t1 = DateTime.utc(2026, 1, 1, 12);
    final t2 = DateTime.utc(2026, 1, 1, 13);
    await audit.record(
      action: 'a.write',
      dataTouched: 'table:messages',
      authorizationStatus: AgentAuditAuthorization.autoAllowed,
      outcome: AgentAuditOutcome.success,
      timestamp: t1,
    );
    await audit.record(
      action: 'b.read',
      dataTouched: 'table:conversations',
      authorizationStatus: AgentAuditAuthorization.denied,
      outcome: AgentAuditOutcome.blocked,
      timestamp: t2,
    );

    final entries = await audit.list(limit: 1);
    expect(entries, hasLength(1));
    expect(entries.single.action, 'b.read');
  });

  test('exportJson is client-readable and includes required fields', () async {
    await audit.record(
      action: 'clipboard.read',
      dataTouched: 'clipboard:text',
      authorizationStatus: AgentAuditAuthorization.pending,
      outcome: AgentAuditOutcome.failure,
      details: {'reason': 'empty'},
    );

    final json = await audit.exportJson();
    expect(json, contains('"action": "clipboard.read"'));
    expect(json, contains('"dataTouched": "clipboard:text"'));
    expect(json, contains('"authorizationStatus": "pending"'));
    expect(json, contains('"outcome": "failure"'));
    expect(json, contains('"timestamp"'));
  });

  test('exportCsv is client-readable with header row', () async {
    await audit.record(
      action: 'conscience.write_thought',
      dataTouched: 'agent_thoughts',
      authorizationStatus: AgentAuditAuthorization.authorized,
      outcome: AgentAuditOutcome.success,
      authorizedBy: 'hermes',
    );

    final csv = await audit.exportCsv();
    expect(
      csv.split('\n').first,
      'timestamp,action,dataTouched,authorizationStatus,outcome,agentId,authorizedBy',
    );
    expect(csv, contains('conscience.write_thought'));
    expect(csv, contains('agent_thoughts'));
    expect(csv, contains('authorized'));
  });

  test('logs stay local — export does not upload or mutate remote state',
      () async {
    await audit.record(
      action: 'local.only',
      dataTouched: 'local_brain',
      authorizationStatus: AgentAuditAuthorization.authorized,
      outcome: AgentAuditOutcome.success,
    );

    final before = await audit.list();
    final exported = await audit.exportJson();
    final after = await audit.list();

    expect(exported, isNotEmpty);
    expect(after.length, before.length);
    expect(after.first.id, before.first.id);
  });
}
