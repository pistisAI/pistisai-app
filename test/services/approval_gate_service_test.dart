import 'package:flutter_test/flutter_test.dart';
import 'package:pistisai/services/approval_gate_service.dart';

void main() {
  late ApprovalGateService gate;

  setUp(() {
    gate = ApprovalGateService();
  });

  tearDown(() {
    gate.dispose();
  });

  CriticalAction dataExportAction({String title = 'Export settings'}) {
    return CriticalAction(
      category: CriticalActionCategory.dataExport,
      title: title,
      summary: 'Write settings JSON to a local file.',
      details: const {'format': 'json'},
      workflowId: 'settings.export',
    );
  }

  CriticalAction integrationAction() {
    return CriticalAction(
      category: CriticalActionCategory.integrationCall,
      title: 'Call external API',
      summary: 'POST device registration to the cloud connector.',
      details: const {'host': 'api.example.com'},
      workflowId: 'cloud.register',
    );
  }

  group('requiresApproval', () {
    test('data export is critical by default', () {
      expect(gate.requiresApproval(dataExportAction()), isTrue);
    });

    test('integration call is critical by default', () {
      expect(gate.requiresApproval(integrationAction()), isTrue);
    });

    test('custom action without flag is not critical', () {
      final action = CriticalAction(
        category: CriticalActionCategory.custom,
        title: 'Local note',
        summary: 'Write a local note only.',
      );
      expect(gate.requiresApproval(action), isFalse);
    });

    test('workflow can force approval on custom actions', () {
      final action = CriticalAction(
        category: CriticalActionCategory.custom,
        title: 'Delete archive',
        summary: 'Delete a local archive.',
        requiresApproval: true,
      );
      expect(gate.requiresApproval(action), isTrue);
    });

    test('workflows can register additional critical action types', () {
      gate.registerCriticalActionType('billing.charge');
      final action = CriticalAction(
        category: CriticalActionCategory.custom,
        title: 'Charge card',
        summary: 'Charge the saved payment method.',
        actionType: 'billing.charge',
      );
      expect(gate.requiresApproval(action), isTrue);
    });
  });

  group('requestApproval / resolve', () {
    test('pauses until user approves', () async {
      final action = dataExportAction();
      final future = gate.requestApproval(action);

      expect(gate.pendingRequests, hasLength(1));
      expect(gate.pendingRequests.first.title, 'Export settings');

      gate.resolve(gate.pendingRequests.first.id, ApprovalVerdict.approved);

      final decision = await future;
      expect(decision.verdict, ApprovalVerdict.approved);
      expect(gate.pendingRequests, isEmpty);
    });

    test('pauses until user denies', () async {
      final future = gate.requestApproval(integrationAction());
      final id = gate.pendingRequests.single.id;

      gate.resolve(id, ApprovalVerdict.denied, note: 'Not now');

      final decision = await future;
      expect(decision.verdict, ApprovalVerdict.denied);
      expect(decision.note, 'Not now');
    });

    test('non-critical actions auto-approve without pending', () async {
      final action = CriticalAction(
        category: CriticalActionCategory.custom,
        title: 'Local cache warm',
        summary: 'Warm local caches only.',
      );

      final decision = await gate.requestApproval(action);

      expect(decision.verdict, ApprovalVerdict.approved);
      expect(gate.pendingRequests, isEmpty);
    });
  });

  group('runCritical', () {
    test('executes only after approval', () async {
      var ran = false;
      final action = dataExportAction();

      final future = gate.runCritical<String>(
        action: action,
        execute: () async {
          ran = true;
          return 'exported';
        },
      );

      expect(ran, isFalse);
      gate.resolve(gate.pendingRequests.single.id, ApprovalVerdict.approved);

      expect(await future, 'exported');
      expect(ran, isTrue);
    });

    test('does not execute when denied', () async {
      var ran = false;
      final future = gate.runCritical<String>(
        action: dataExportAction(),
        execute: () async {
          ran = true;
          return 'exported';
        },
      );

      gate.resolve(gate.pendingRequests.single.id, ApprovalVerdict.denied);

      await expectLater(future, throwsA(isA<ApprovalDeniedException>()));
      expect(ran, isFalse);
    });

    test('runs immediately when approval is not required', () async {
      final result = await gate.runCritical<int>(
        action: CriticalAction(
          category: CriticalActionCategory.custom,
          title: 'noop',
          summary: 'nothing sensitive',
        ),
        execute: () async => 42,
      );
      expect(result, 42);
    });
  });

  group('audit trail', () {
    test('logs each approval decision', () async {
      final approveFuture = gate.requestApproval(dataExportAction());
      gate.resolve(gate.pendingRequests.single.id, ApprovalVerdict.approved);
      await approveFuture;

      final denyFuture = gate.requestApproval(integrationAction());
      gate.resolve(
        gate.pendingRequests.single.id,
        ApprovalVerdict.denied,
        note: 'blocked',
      );
      await denyFuture;

      expect(gate.auditTrail, hasLength(2));
      expect(gate.auditTrail[0].verdict, ApprovalVerdict.approved);
      expect(gate.auditTrail[0].action.category, CriticalActionCategory.dataExport);
      expect(gate.auditTrail[1].verdict, ApprovalVerdict.denied);
      expect(gate.auditTrail[1].note, 'blocked');
    });

    test('persists decisions through conscience storage when provided', () async {
      final recorded = <Map<String, dynamic>>[];
      final gateWithAudit = ApprovalGateService(
        auditLogger: (entry) async {
          recorded.add({
            'action': entry.action.title,
            'verdict': entry.verdict.name,
            'summary': entry.action.summary,
          });
        },
      );
      addTearDown(gateWithAudit.dispose);

      final future = gateWithAudit.requestApproval(dataExportAction());
      gateWithAudit.resolve(
        gateWithAudit.pendingRequests.single.id,
        ApprovalVerdict.approved,
      );
      await future;

      expect(recorded, hasLength(1));
      expect(recorded.single['action'], 'Export settings');
      expect(recorded.single['verdict'], 'approved');
    });
  });
}
