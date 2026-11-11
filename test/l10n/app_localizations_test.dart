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
import 'package:pistisai/screens/debug/debug_screen.dart';
import 'package:pistisai/services/connection_manager_service.dart';
import 'package:pistisai/services/hermes/hermes_streaming_service.dart';
import 'package:pistisai/services/settings_preference_service.dart';
import 'package:provider/provider.dart';
import 'package:pistisai/screens/nodes/nodes_screen.dart';
import 'package:pistisai/screens/onboarding/steps/welcome_step.dart';
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
    expect(fr.configClearCacheConfirmMeasured('12 Mo'),
        "Supprimer l'audio de synthèse vocale et les images en cache ? (12 Mo sur le disque)");
    expect(fr.configCacheClearedFreed('12 Mo'), 'Cache vidé (12 Mo libérés)');
    expect(fr.configRuntimeSet('Hermes Agent'),
        'Environnement actif : Hermes Agent');
    expect(fr.configUpdateAvailable('3.2.0'), 'Mise à jour disponible : 3.2.0');
    expect(fr.configWhatsNew('3.2.0'), 'Nouveautés de la version 3.2.0');
  });

  test('batch 10 file and debug messages follow each language rules', () {
    final en = lookupAppLocalizations(const Locale('en'));
    final fr = lookupAppLocalizations(const Locale('fr'));
    expect(en.filesDeleteConfirm(1), 'Are you sure you want to delete 1 item?');
    expect(fr.filesDeleteConfirm(3),
        'Voulez-vous vraiment supprimer 3 éléments ?');
    expect(fr.filesSelected(1), '1 sélectionné');
    expect(fr.filesSizeKb('12.5'), '12.5 Ko');
    expect(fr.debugModelsAvailable(2), '2 modèles disponibles');
  });

  testWidgets('the debug screen renders in French for a locked brand',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final connectionManager = ConnectionManagerService(
      hermesStreamingService: HermesStreamingService(),
      settingsPreferenceService: SettingsPreferenceService(),
      autoDetectOnInitialize: false,
    );
    addTearDown(connectionManager.dispose);
    await tester.pumpWidget(
      ChangeNotifierProvider<ConnectionManagerService>.value(
        value: connectionManager,
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          locale: const Locale('fr'),
          localizationsDelegates: brandLocalizationsDelegates,
          supportedLocales: const [Locale('fr'), Locale('en')],
          home: const DebugScreen(),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Débogage'), findsOneWidget);
    expect(find.text('Diagnostic de connexion'), findsOneWidget);
    expect(find.text('Debug'), findsNothing);
  });

  test('batch 11 setup wizard messages read naturally in French', () {
    final fr = lookupAppLocalizations(const Locale('fr'));
    expect(fr.wizardStepOf(2, 6), 'Étape 2 sur 6');
    expect(fr.locationTitle, 'Où Hermes fonctionne-t-il ?');
    expect(fr.connConnectingTo('http://127.0.0.1:8642'),
        'Connexion à : http://127.0.0.1:8642');
    expect(fr.botInstallFailed('agent'), "Échec de l'installation : agent");
  });

  testWidgets('the setup wizard welcome step renders in French',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        locale: Locale('fr'),
        localizationsDelegates: brandLocalizationsDelegates,
        supportedLocales: [Locale('fr'), Locale('en')],
        home: Scaffold(body: WelcomeStep()),
      ),
    );
    await tester.pump();
    expect(find.textContaining('Nous allons configurer votre IA locale'),
        findsOneWidget);
    expect(find.textContaining("We'll set up your local AI"), findsNothing);
  });

  test('batch 12 admin messages read naturally in French', () {
    final fr = lookupAppLocalizations(const Locale('fr'));
    expect(fr.adminUsersShowing(1, 50, 120), 'Utilisateurs 1 à 50 sur 120');
    expect(fr.adminPageOf(2, 3), 'Page 2 sur 3');
    expect(fr.adminConversionRate('4.2'), 'Taux de conversion : 4.2 %');
    expect(fr.adminCountPercent(12, '34.0'), '12 (34.0 %)');
    expect(fr.adminUserLabel('a@example.com'), 'Utilisateur : a@example.com');
  });

  test('batch 13 audit and admin messages read naturally in French', () {
    final fr = lookupAppLocalizations(const Locale('fr'));
    expect(fr.auditShowing(1, 25, 300), 'Entrées 1 à 25 sur 300');
    expect(fr.auditFilterFrom('2026-11-01'), 'Du : 2026-11-01');
    expect(fr.adminsRevokeConfirm(fr.adminsRoleFinance, 'a@example.com'),
        'Voulez-vous vraiment retirer le rôle Administrateur des finances à a@example.com ?');
    expect(fr.adminsWeeksAgo(2), 'il y a 2 sem.');
  });
}
