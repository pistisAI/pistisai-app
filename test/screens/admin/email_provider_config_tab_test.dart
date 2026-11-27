// The backend has no POST /admin/email/config route, so the provider save
// control must be disabled and labelled, not offered (AGENTS.md: controls
// tell the truth). See #1004.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pistisai/di/locator.dart' as di;
import 'package:pistisai/l10n/app_localizations.dart';
import 'package:pistisai/screens/admin/email_provider_config_tab.dart';
import 'package:pistisai/services/admin_center_service.dart';

import '../../helpers/mock_services.dart';

class _FakeEmailAdminService extends MockAdminCenterService {
  int saveCalls = 0;

  @override
  Future<Map<String, dynamic>> getEmailConfiguration() async => {
        'configurations': [
          {
            'provider': 'smtp',
            'smtp_host': 'smtp.example.com',
            'smtp_port': 587,
            'smtp_username': 'dev@example.com',
            'encryption': 'tls',
          },
        ],
      };

  @override
  Future<Map<String, dynamic>> saveEmailConfiguration(
    Map<String, dynamic> config,
  ) async {
    saveCalls++;
    return {};
  }
}

Widget _wrap(Widget child) => MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: child),
    );

void main() {
  late _FakeEmailAdminService service;

  setUp(() async {
    await di.serviceLocator.reset();
    service = _FakeEmailAdminService();
    di.serviceLocator.registerSingleton<AdminCenterService>(service);
  });

  tearDown(() async {
    await di.serviceLocator.reset();
  });

  testWidgets('save is disabled and labelled not available yet',
      (tester) async {
    tester.view.physicalSize = const Size(1600, 3200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    // The encryption dropdown overflows with the test font; layout is not
    // what this test checks.
    final previousOnError = FlutterError.onError;
    FlutterError.onError = (details) {
      if (details.exceptionAsString().contains('RenderFlex overflowed')) {
        return;
      }
      previousOnError?.call(details);
    };
    addTearDown(() => FlutterError.onError = previousOnError);

    await tester.pumpWidget(
      _wrap(const EmailProviderConfigTab(selfHostedOverride: true)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Save Configuration'), findsNothing);
    expect(find.text('Save (not available yet)'), findsOneWidget);
    expect(
      find.textContaining('Saving email provider settings is not available yet'),
      findsOneWidget,
    );

    final button = tester.widget<ButtonStyleButton>(
      find.byKey(const Key('email_config_save_button')),
    );
    expect(button.onPressed, isNull);

    await tester.tap(
      find.byKey(const Key('email_config_save_button')),
      warnIfMissed: false,
    );
    await tester.pumpAndSettle();

    expect(service.saveCalls, 0);
    expect(find.textContaining('saved successfully'), findsNothing);
  });
}
