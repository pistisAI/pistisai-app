import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pistisai/brand/brand_localizations.dart';
import 'package:pistisai/l10n/app_localizations.dart';
import 'package:pistisai/components/welcome_screen.dart';
import 'package:pistisai/config/theme.dart';
import 'package:pistisai/screens/agents/agents_screen.dart';
import 'package:pistisai/screens/avatar/avatar_customization_screen.dart';
import 'package:pistisai/screens/cron/cron_jobs_screen.dart';
import 'package:pistisai/screens/nodes/nodes_screen.dart';
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

  test('batch 4 messages with values read naturally in French', () {
    final fr = lookupAppLocalizations(const Locale('fr'));
    expect(fr.nodesSelectedRuntime('Hermes', '1.2.3'),
        'Environnement d\'agent : Hermes (1.2.3)');
    expect(fr.logsDetailLabel(fr.logsSource), 'Source :');
    expect(fr.commonErrorDetails('boom'), 'Erreur : boom');
    expect(fr.channelMinutesAgo(5), 'il y a 5 min');
    expect(fr.usageOfLimit(8), 'sur 8');
  });

  testWidgets('the nodes screen renders in French for a locked brand',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        locale: Locale('fr'),
        localizationsDelegates: brandLocalizationsDelegates,
        supportedLocales: [Locale('fr'), Locale('en')],
        home: NodesScreen(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Nœuds'), findsOneWidget);
    expect(
        find.text('Aucun environnement d\'agent sélectionné'), findsOneWidget);
    expect(find.text('Appareils Tailscale'), findsOneWidget);
    expect(find.text('Nodes'), findsNothing);
  });

  test('batch 5 messages follow each language rules', () {
    final en = lookupAppLocalizations(const Locale('en'));
    final fr = lookupAppLocalizations(const Locale('fr'));
    expect(en.channelsMessageCount(1), '1 message');
    expect(en.channelsMessageCount(4), '4 messages');
    expect(fr.channelsMessageCount(0), '0 message');
    expect(fr.channelsMessageCount(4), '4 messages');
    expect(fr.agentsRemoveConfirm('bot'), 'Voulez-vous vraiment retirer bot ?');
    expect(fr.commonFieldLabel(fr.commonStatus), 'État :');
    expect(fr.sessionsDurationHoursMinutes(2, 5), '2 h 5 min');
    expect(fr.timeSecondsAgo(30), 'il y a 30 s');
  });

  testWidgets('the agents screen renders in French for a locked brand',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        locale: Locale('fr'),
        localizationsDelegates: brandLocalizationsDelegates,
        supportedLocales: [Locale('fr'), Locale('en')],
        home: AgentsScreen(),
      ),
    );
    await tester.pump();
    expect(find.text('Registre'), findsOneWidget);
    expect(find.text('Aucun agent enregistré'), findsOneWidget);
    expect(find.byTooltip('Ajouter un agent'), findsOneWidget);
    expect(find.text('Registry'), findsNothing);
  });

  test('agent possessives read naturally in both languages', () {
    final en = lookupAppLocalizations(const Locale('en'));
    final fr = lookupAppLocalizations(const Locale('fr'));
    expect(en.homeMoodTitle("Aria's", 'Aria'), "Aria's Mood");
    expect(fr.homeMoodTitle("Aria's", 'Aria'), "Humeur de l'agent Aria");
    expect(fr.homeToolsTitle('Aria'), "Ce que l'agent Aria peut faire");
    expect(fr.homeMessagePlaceholder('Aria'), 'Écrire à Aria…');
  });

  testWidgets('the welcome screen renders in French for a locked brand',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        locale: const Locale('fr'),
        localizationsDelegates: brandLocalizationsDelegates,
        supportedLocales: const [Locale('fr'), Locale('en')],
        home: WelcomeScreen(onNewChat: () {}),
      ),
    );
    await tester.pump();
    expect(
        find.textContaining('Écrivez un message ci-dessous'), findsOneWidget);
    expect(find.textContaining('Type a message below'), findsNothing);
  });

  test('batch 7 messages follow each language rules', () {
    final en = lookupAppLocalizations(const Locale('en'));
    final fr = lookupAppLocalizations(const Locale('fr'));
    expect(en.skillsUsesCount(1), '1 use');
    expect(fr.skillsUsesCount(1), '1 utilisation');
    expect(fr.skillsUsesCount(3), '3 utilisations');
    expect(fr.cronDeleteConfirm('Sauvegarde'),
        'Voulez-vous vraiment supprimer « Sauvegarde » ? Cette action est irréversible.');
    expect(fr.instancesUtilized(80), '80 % utilisé');
    expect(fr.instancesUptimeDaysHours(2, 3), '2 j 3 h');
  });

  testWidgets('the cron jobs screen renders in French for a locked brand',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        locale: Locale('fr'),
        localizationsDelegates: brandLocalizationsDelegates,
        supportedLocales: [Locale('fr'), Locale('en')],
        home: CronJobsScreen(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Tâches planifiées'), findsOneWidget);
    expect(find.text('Aucune tâche planifiée'), findsOneWidget);
    expect(find.text('Cron Jobs'), findsNothing);
  });

  test('batch 8 avatar messages read naturally in French', () {
    final fr = lookupAppLocalizations(const Locale('fr'));
    expect(fr.avatarRequirementPercent(45, 60), '45 % / 60 %');
    expect(fr.achievementsUnlockedCount(2, 8), '2 sur 8 débloqués');
    expect(
        fr.achievementsUnlockedWhen(fr.achievementsYesterday), 'Débloqué hier');
    expect(fr.achievementEvolveDescription(fr.avatarStageWiseCompanion),
        "Faire évoluer votre avatar jusqu'au stade Compagnon sage");
    expect(fr.avatarEvolutionDenied('trop tôt'),
        "Demande d'évolution refusée : trop tôt");
  });

  testWidgets('the avatar customization screen renders in French',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      MaterialApp.router(
        theme: AppTheme.darkTheme,
        locale: const Locale('fr'),
        localizationsDelegates: brandLocalizationsDelegates,
        supportedLocales: const [Locale('fr'), Locale('en')],
        routerConfig: GoRouter(
          routes: [
            GoRoute(
              path: '/',
              builder: (context, state) => const AvatarCustomizationScreen(),
            ),
          ],
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text("Personnalisation de l'avatar"), findsOneWidget);
    expect(find.text('Avatar Customization'), findsNothing);
  });

  test('batch 9 configuration messages read naturally in French', () {
    final fr = lookupAppLocalizations(const Locale('fr'));
    expect(fr.configClearCacheConfirm(500),
        'Vider toutes les données en cache ? (500 Mo seront libérés)');
    expect(fr.configRuntimeSet('Hermes Agent'),
        'Environnement actif : Hermes Agent');
    expect(fr.configUpdateAvailable('3.2.0'), 'Mise à jour disponible : 3.2.0');
    expect(fr.configWhatsNew('3.2.0'), 'Nouveautés de la version 3.2.0');
  });
}
