// "Validate All" may only report success when the backend says the records
// are valid (AGENTS.md: controls tell the truth). See #1004.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pistisai/di/locator.dart' as di;
import 'package:pistisai/l10n/app_localizations.dart';
import 'package:pistisai/screens/admin/dns_config_tab.dart';
import 'package:pistisai/services/admin_center_service.dart';

import '../../helpers/mock_services.dart';

class _FakeDnsAdminService extends MockAdminCenterService {
  _FakeDnsAdminService(this.result);

  final DnsValidationResult result;

  @override
  Future<List<Map<String, dynamic>>> getDnsRecords({
    String? recordType,
    String? name,
  }) async =>
      [];

  @override
  Future<DnsValidationResult> validateDnsRecords({String? recordId}) async =>
      result;
}

Widget _wrap(Widget child) => MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: child),
    );

void main() {
  tearDown(() async {
    await di.serviceLocator.reset();
  });

  Future<void> pumpAndValidate(
    WidgetTester tester,
    DnsValidationResult result,
  ) async {
    await di.serviceLocator.reset();
    di.serviceLocator
        .registerSingleton<AdminCenterService>(_FakeDnsAdminService(result));
    tester.view.physicalSize = const Size(1600, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_wrap(const DnsConfigTab()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Validate All'));
    await tester.pumpAndSettle();
  }

  testWidgets('invalid records are listed and success is not shown',
      (tester) async {
    await pumpAndValidate(
      tester,
      const DnsValidationResult(
        valid: false,
        errors: [
          DnsValidationError(
            recordId: 'rec-1',
            recordType: 'SPF',
            message: 'Record not found in DNS',
          ),
        ],
      ),
    );

    expect(find.textContaining('validated successfully'), findsNothing);
    expect(find.text('All DNS records passed validation'), findsNothing);
    expect(
      find.textContaining('Some DNS records failed validation'),
      findsOneWidget,
    );
    expect(
      find.textContaining('SPF: Record not found in DNS'),
      findsOneWidget,
    );
  });

  testWidgets('invalid result without details still is not a success',
      (tester) async {
    await pumpAndValidate(
      tester,
      const DnsValidationResult(valid: false),
    );

    expect(find.text('All DNS records passed validation'), findsNothing);
    expect(
      find.textContaining('Some DNS records failed validation'),
      findsOneWidget,
    );
  });

  testWidgets('valid result shows success', (tester) async {
    await pumpAndValidate(
      tester,
      const DnsValidationResult(valid: true),
    );

    expect(find.text('All DNS records passed validation'), findsOneWidget);
    expect(
      find.textContaining('Some DNS records failed validation'),
      findsNothing,
    );
  });
}
