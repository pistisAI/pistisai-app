// Deleting a live DNS record needs an explicit confirmation that names the
// record (AGENTS.md: a person approves deletions). See #1004.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pistisai/di/locator.dart' as di;
import 'package:pistisai/l10n/app_localizations.dart';
import 'package:pistisai/screens/admin/dns_config_tab.dart';
import 'package:pistisai/services/admin_center_service.dart';

import '../../helpers/mock_services.dart';

class _FakeDnsAdminService extends MockAdminCenterService {
  final List<String> deletedIds = [];

  @override
  Future<List<Map<String, dynamic>>> getDnsRecords({
    String? recordType,
    String? name,
  }) async =>
      [
        {
          'id': 'rec-1',
          'recordType': 'MX',
          'name': 'mail.example.com',
          'value': '10 mx.example.com',
          'ttl': 3600,
          'status': 'valid',
        },
      ];

  @override
  Future<void> deleteDnsRecord(String recordId) async {
    deletedIds.add(recordId);
  }
}

Widget _wrap(Widget child) => MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: child),
    );

void main() {
  late _FakeDnsAdminService service;

  setUp(() async {
    await di.serviceLocator.reset();
    service = _FakeDnsAdminService();
    di.serviceLocator.registerSingleton<AdminCenterService>(service);
  });

  tearDown(() async {
    await di.serviceLocator.reset();
  });

  Future<void> pumpTab(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1600, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_wrap(const DnsConfigTab()));
    await tester.pumpAndSettle();
  }

  testWidgets('delete asks for confirmation naming the record',
      (tester) async {
    await pumpTab(tester);

    await tester.tap(find.byTooltip('Delete Record'));
    await tester.pumpAndSettle();

    expect(service.deletedIds, isEmpty,
        reason: 'one click must not delete a live DNS record');
    expect(find.byType(AlertDialog), findsOneWidget);
    final dialog = find.byType(AlertDialog);
    expect(
      find.descendant(
        of: dialog,
        matching: find.textContaining('MX'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: dialog,
        matching: find.textContaining('mail.example.com'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('cancelling the dialog keeps the record', (tester) async {
    await pumpTab(tester);

    await tester.tap(find.byTooltip('Delete Record'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    expect(service.deletedIds, isEmpty);
  });

  testWidgets('confirming the dialog deletes that record', (tester) async {
    await pumpTab(tester);

    await tester.tap(find.byTooltip('Delete Record'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete record'));
    await tester.pumpAndSettle();

    expect(service.deletedIds, ['rec-1']);
  });
}
