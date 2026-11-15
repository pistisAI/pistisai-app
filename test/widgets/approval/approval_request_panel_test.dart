import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pistisai/l10n/app_localizations.dart';
import 'package:pistisai/services/approval_gate_service.dart';
import 'package:pistisai/widgets/approval/approval_request_panel.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('shows action summary and resolves approve/deny', (tester) async {
    final gate = ApprovalGateService();
    addTearDown(gate.dispose);

    await tester.pumpWidget(
      ChangeNotifierProvider<ApprovalGateService>.value(
        value: gate,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const ApprovalGateHost(
            child: Scaffold(body: Text('content')),
          ),
        ),
      ),
    );

    final future = gate.requestApproval(
      CriticalAction(
        category: CriticalActionCategory.dataExport,
        title: 'Export settings',
        summary: 'Write settings JSON to a local file.',
        details: const {'filename': 'settings.json'},
        workflowId: 'settings.export',
      ),
    );
    await tester.pump();

    expect(find.text('Approval required'), findsOneWidget);
    expect(find.text('Export settings'), findsOneWidget);
    expect(find.text('Write settings JSON to a local file.'), findsOneWidget);
    expect(find.text('filename: settings.json'), findsOneWidget);
    expect(find.text('Workflow: settings.export'), findsOneWidget);

    await tester.tap(find.text('Approve'));
    await tester.pump();

    final decision = await future;
    expect(decision.verdict, ApprovalVerdict.approved);
    expect(find.text('Approval required'), findsNothing);
    expect(gate.auditTrail, hasLength(1));
  });

  testWidgets('deny button records denied decision', (tester) async {
    final gate = ApprovalGateService();
    addTearDown(gate.dispose);

    await tester.pumpWidget(
      ChangeNotifierProvider<ApprovalGateService>.value(
        value: gate,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const ApprovalGateHost(
            child: Scaffold(body: Text('content')),
          ),
        ),
      ),
    );

    final future = gate.requestApproval(
      CriticalAction(
        category: CriticalActionCategory.integrationCall,
        title: 'Revoke device',
        summary: 'Revoke cloud connector access.',
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Deny'));
    await tester.pump();

    final decision = await future;
    expect(decision.verdict, ApprovalVerdict.denied);
    expect(gate.auditTrail.single.verdict, ApprovalVerdict.denied);
  });
}
