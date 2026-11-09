import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pistisai/brand/brand_localizations.dart';
import 'package:pistisai/l10n/app_localizations.dart';
import 'package:pistisai/screens/settings/llm_provider_settings_screen.dart';

Set<String> _arbKeys(String path) {
  final json =
      jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;
  return json.keys.where((k) => !k.startsWith('@')).toSet();
}

Widget _app(Locale? locale, List<LocalizationsDelegate<dynamic>> delegates) {
  return MaterialApp(
    locale: locale,
    localizationsDelegates: delegates,
    supportedLocales: const [Locale('fr'), Locale('en')],
    home: Builder(
      builder: (context) =>
          Text(AppLocalizations.of(context).settingsGeneralTitle),
    ),
  );
}

void main() {
  test('every English string has a French translation', () {
    final en = _arbKeys('lib/l10n/app_en.arb');
    final fr = _arbKeys('lib/l10n/app_fr.arb');
    expect(fr.difference(en), isEmpty,
        reason: 'French keys missing in English');
    expect(en.difference(fr), isEmpty,
        reason: 'English keys missing in French');
  });

  test('French and English are supported', () {
    final codes =
        AppLocalizations.supportedLocales.map((l) => l.languageCode).toSet();
    expect(codes, containsAll(<String>['en', 'fr']));
  });

  test('French strings resolve', () {
    final fr = lookupAppLocalizations(const Locale('fr'));
    expect(fr.settingsGeneralTitle, 'Paramètres généraux');
    expect(fr.themeDark, 'Sombre');
  });

  testWidgets('a locked French brand shows French app strings', (tester) async {
    await tester.pumpWidget(
      _app(const Locale('fr'), brandLocalizationsDelegates),
    );
    await tester.pumpAndSettle();
    expect(find.text('Paramètres généraux'), findsOneWidget);
  });

  testWidgets('English stays the default', (tester) async {
    await tester.pumpWidget(
      _app(const Locale('en'), const [AppLocalizations.delegate]),
    );
    await tester.pumpAndSettle();
    expect(find.text('General Settings'), findsOneWidget);
  });

  test('French messages with values keep French punctuation', () {
    final fr = lookupAppLocalizations(const Locale('fr'));
    expect(
      fr.visionResultError(fr.visionOcrService, 'timeout'),
      '❌ Service de reconnaissance de texte (OCR) : timeout',
    );
    expect(fr.meshLastSeen('hier'), 'dernière connexion : hier');
  });

  testWidgets('a settings screen renders in French for a locked brand',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        locale: Locale('fr'),
        localizationsDelegates: brandLocalizationsDelegates,
        supportedLocales: [Locale('fr'), Locale('en')],
        home: LLMProviderSettingsScreen(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Fournisseurs de modèles'), findsOneWidget);
    expect(find.text('Ouvrir la configuration'), findsOneWidget);
    expect(find.text('LLM Provider Settings'), findsNothing);
  });

  test('model counts use each language plural rules', () {
    final en = lookupAppLocalizations(const Locale('en'));
    final fr = lookupAppLocalizations(const Locale('fr'));
    expect(en.daemonModelCount(1), '1 model');
    expect(en.daemonModelCount(0), '0 models');
    expect(en.daemonModelCount(3), '3 models');
    expect(fr.daemonModelCount(0), '0 modèle');
    expect(fr.daemonModelCount(1), '1 modèle');
    expect(fr.daemonModelCount(3), '3 modèles');
  });
}
