import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:pistisai/database/drift_local_brain.dart';
import 'package:pistisai/services/approval_gate_service.dart';
import 'package:pistisai/services/conscience_storage_service.dart';
import 'package:pistisai/services/rate_limit_manager.dart';
import 'package:pistisai/services/router_server.dart';

/// The human approval trail (AGENTS.md: "A person approves sends and critical
/// actions") must not be writable by loopback HTTP callers of the router.
void main() {
  setUpAll(() {
    HttpOverrides.global = null;
  });

  late LocalBrain brain;
  late ConscienceStorageService storage;
  late RouterServer server;
  late Uri baseUrl;

  setUp(() async {
    brain = LocalBrain.withExecutor(NativeDatabase.memory());
    storage = ConscienceStorageService(database: brain);
    final port = await _availableLoopbackPort();
    // No authSecret: loopback callers pass the access check without a token.
    server = RouterServer(
      port: port,
      rateLimitManager: RateLimitManager(brain),
      providers: const {},
      conscienceStorage: storage,
    );
    await server.start();
    baseUrl = Uri.parse('http://127.0.0.1:$port');
  });

  tearDown(() async {
    await server.stop();
    await brain.close();
  });

  Future<http.Response> post(Map<String, dynamic> body) => http.post(
        baseUrl.replace(path: '/api/conscience/decisions'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );

  Future<http.Response> putVerdict(Map<String, dynamic> body) => http.put(
        baseUrl.replace(path: '/api/conscience/decisions/verdict'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );

  test('loopback PUT cannot flip a user DENIED decision to APPROVED', () async {
    final denied = await storage.recordHumanApproval(
      action: 'dataExport: Export settings',
      riskLevel: 'critical',
      approved: false,
      reasoning: 'Not now',
    );
    final id = denied['id'] as String;

    final response = await putVerdict({
      'decision_id': id,
      'verdict': 'APPROVED',
      'reviewer': 'agent',
      'reasoning': 'override',
    });

    expect(response.statusCode, HttpStatus.forbidden);
    final stored = await brain.getDecisionById(id);
    expect(stored!.verdict, 'DENIED');
    expect(stored.reviewer, 'user');
    expect(stored.reasoning, 'Not now');
  });

  test('loopback PUT cannot change an agent decision with a final verdict',
      () async {
    final created = await storage.writeDecision(
      action: 'Update config',
      riskLevel: 'high',
      verdict: 'DENIED',
      reviewer: 'agent',
      reasoning: 'Unsafe',
    );
    final id = created['id'] as String;

    final response = await putVerdict({
      'decision_id': id,
      'verdict': 'APPROVED',
      'reviewer': 'agent',
      'reasoning': 'changed my mind',
    });

    expect(response.statusCode, HttpStatus.forbidden);
    expect((await brain.getDecisionById(id))!.verdict, 'DENIED');
  });

  test('POST with reviewer "user" is refused, whatever the case or spacing',
      () async {
    for (final reviewer in ['user', ' User ', 'USER']) {
      final response = await post({
        'action': 'Send invoice',
        'risk_level': 'critical',
        'verdict': 'APPROVED',
        'reviewer': reviewer,
        'reasoning': 'forged',
      });
      expect(response.statusCode, HttpStatus.forbidden, reason: reviewer);
    }
    expect(await brain.getAllDecisions(), isEmpty);
  });

  test('PUT with reviewer "user" is refused on a pending decision', () async {
    final pending = await storage.writeDecision(
      action: 'Delete file',
      riskLevel: 'high',
    );
    final id = pending['id'] as String;

    final response = await putVerdict({
      'decision_id': id,
      'verdict': 'APPROVED',
      'reviewer': 'User',
      'reasoning': 'forged',
    });

    expect(response.statusCode, HttpStatus.forbidden);
    final stored = await brain.getDecisionById(id);
    expect(stored!.status, 'pending');
    expect(stored.verdict, isNull);
  });

  test('invalid verdicts are refused on POST and PUT', () async {
    final postResponse = await post({
      'action': 'Update config',
      'risk_level': 'medium',
      'verdict': 'APPROVED_BY_USER',
      'reviewer': 'agent',
    });
    expect(postResponse.statusCode, HttpStatus.badRequest);

    final pending = await storage.writeDecision(
      action: 'Update config',
      riskLevel: 'medium',
    );
    final putResponse = await putVerdict({
      'decision_id': pending['id'],
      'verdict': 'MAYBE',
      'reviewer': 'agent',
      'reasoning': 'unsure',
    });
    expect(putResponse.statusCode, HttpStatus.badRequest);
    expect((await brain.getDecisionById(pending['id'] as String))!.status,
        'pending');
  });

  test('agent-authored decisions still work over HTTP', () async {
    final created = await post({
      'action': 'Update config',
      'risk_level': 'medium',
      'reviewer': 'agent',
    });
    expect(created.statusCode, HttpStatus.ok);
    final id = ((jsonDecode(created.body) as Map<String, dynamic>)['decision']
        as Map<String, dynamic>)['id'] as String;

    final hold = await putVerdict({
      'decision_id': id,
      'verdict': 'hold',
      'reviewer': 'agent',
      'reasoning': 'needs more info',
    });
    expect(hold.statusCode, HttpStatus.ok);

    final approved = await putVerdict({
      'decision_id': id,
      'verdict': 'APPROVED',
      'reviewer': 'agent',
      'reasoning': 'checks passed',
    });
    expect(approved.statusCode, HttpStatus.ok);
    final stored = await brain.getDecisionById(id);
    expect(stored!.verdict, 'APPROVED');
    expect(stored.reviewer, 'agent');
  });

  test('ApprovalGateService still records the user decision', () async {
    final gate = ApprovalGateService(
      auditLogger: conscienceApprovalAuditLogger(storage),
    );
    addTearDown(gate.dispose);

    final future = gate.requestApproval(CriticalAction(
      category: CriticalActionCategory.dataExport,
      title: 'Export settings',
      summary: 'Write settings JSON to a local file.',
    ));
    gate.resolve(gate.pendingRequests.single.id, ApprovalVerdict.denied,
        note: 'Not now');
    await future;

    List<ConscienceDecision> decisions = const [];
    for (var i = 0; i < 50 && decisions.isEmpty; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
      decisions = await brain.getAllDecisions();
    }
    expect(decisions, hasLength(1));
    expect(decisions.single.reviewer, 'user');
    expect(decisions.single.verdict, 'DENIED');
    expect(decisions.single.reasoning, 'Not now');
    expect(decisions.single.riskLevel, 'critical');
  });
}

Future<int> _availableLoopbackPort() async {
  final socket = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
  final port = socket.port;
  await socket.close();
  return port;
}
