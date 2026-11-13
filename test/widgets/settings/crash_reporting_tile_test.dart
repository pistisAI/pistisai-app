import 'package:pistisai/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pistisai/services/settings_preference_service.dart';
import 'package:pistisai/widgets/settings/crash_reporting_tile.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _pump(WidgetTester tester, {bool configured = true}) async {
  await tester.pumpWidget(MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: CrashReportingTile(reportingConfigured: configured),
    ),
  ));
  await tester.pumpAndSettle();
}

SwitchListTile _tile(WidgetTester tester) =>
    tester.widget<SwitchListTile>(find.byType(SwitchListTile));

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('is off by default', (tester) async {
    await _pump(tester);

    expect(_tile(tester).value, isFalse);
    expect(_tile(tester).onChanged, isNotNull);
    expect(find.textContaining('Off by default'), findsOneWidget);
  });

  testWidgets('turning it on saves the preference', (tester) async {
    await _pump(tester);

    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();

    expect(_tile(tester).value, isTrue);
    expect(await SettingsPreferenceService().isCrashReportingEnabled(), isTrue);
    expect(find.textContaining('next time the app starts'), findsOneWidget);
  });

  testWidgets('turning it off again saves the preference', (tester) async {
    SharedPreferences.setMockInitialValues(
        {'settings_crash_reporting_enabled': true});
    await _pump(tester);
    expect(_tile(tester).value, isTrue);

    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();

    expect(_tile(tester).value, isFalse);
    expect(
        await SettingsPreferenceService().isCrashReportingEnabled(), isFalse);
  });

  testWidgets('is disabled when the build cannot send reports', (tester) async {
    await _pump(tester, configured: false);

    expect(_tile(tester).onChanged, isNull);
    expect(find.textContaining('cannot send crash reports'), findsOneWidget);
  });
}
