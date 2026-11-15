import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pistisai/l10n/app_localizations.dart';
import 'package:pistisai/services/settings_preference_service.dart';
import 'package:pistisai/widgets/settings/cloud_llm_providers_tile.dart';
import 'package:pistisai/widgets/settings/microsoft_speech_tile.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _pump(WidgetTester tester, Widget child) async {
  await tester.pumpWidget(MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: child),
  ));
  await tester.pumpAndSettle();
}

SwitchListTile _tile(WidgetTester tester) =>
    tester.widget<SwitchListTile>(find.byType(SwitchListTile));

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('cloud LLM providers tile is off by default', (tester) async {
    await _pump(tester, const CloudLlmProvidersTile());

    expect(_tile(tester).value, isFalse);
    expect(find.textContaining('Off by default'), findsOneWidget);
  });

  testWidgets('cloud LLM providers tile saves opt-in', (tester) async {
    await _pump(tester, const CloudLlmProvidersTile());

    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();

    expect(_tile(tester).value, isTrue);
    expect(
      await SettingsPreferenceService().isCloudLlmProvidersEnabled(),
      isTrue,
    );
  });

  testWidgets('Microsoft speech tile is off by default', (tester) async {
    await _pump(tester, const MicrosoftSpeechTile());

    expect(_tile(tester).value, isFalse);
    expect(find.textContaining('Off by default'), findsOneWidget);
  });

  testWidgets('Microsoft speech tile saves opt-in', (tester) async {
    await _pump(tester, const MicrosoftSpeechTile());

    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();

    expect(_tile(tester).value, isTrue);
    expect(
      await SettingsPreferenceService().isMicrosoftSpeechEnabled(),
      isTrue,
    );
  });
}
