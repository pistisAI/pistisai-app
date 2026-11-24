// Config screen controls must be applied by the app, or not shown (#854).
@Timeout(Duration(minutes: 3))
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pistisai/di/locator.dart';
import 'package:pistisai/l10n/app_localizations.dart';
import 'package:pistisai/screens/config/config_screen.dart';
import 'package:pistisai/services/auto_update_service.dart';
import 'package:pistisai/services/connection_manager_service.dart';
import 'package:pistisai/services/hermes/hermes_streaming_service.dart';
import 'package:pistisai/services/settings_import_export_service.dart';
import 'package:pistisai/services/settings_preference_service.dart'
    as settings;
import 'package:pistisai/services/theme_provider.dart';
import 'package:pistisai/services/window_manager_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Config screen (#854)', () {
    late settings.SettingsPreferenceService settingsService;
    late ConnectionManagerService connectionManager;
    late ThemeProvider themeProvider;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await serviceLocator.reset();
      settingsService = settings.SettingsPreferenceService();
      serviceLocator.registerSingleton<settings.SettingsPreferenceService>(
        settingsService,
      );
      serviceLocator.registerSingleton<SettingsImportExportService>(
        SettingsImportExportService(preferencesService: settingsService),
      );
      connectionManager = ConnectionManagerService(
        hermesStreamingService: HermesStreamingService(),
        settingsPreferenceService: settingsService,
        autoDetectOnInitialize: false,
      );
      themeProvider = ThemeProvider(skipLoad: true);
    });

    tearDown(() async {
      connectionManager.dispose();
      await serviceLocator.reset();
    });

    Future<void> pumpConfig(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1400, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final router = GoRouter(
        initialLocation: '/config',
        routes: [
          GoRoute(
            path: '/config',
            builder: (context, state) => const ConfigScreen(),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<ConnectionManagerService>.value(
              value: connectionManager,
            ),
            ChangeNotifierProvider<AutoUpdateService>.value(
              value: AutoUpdateService(),
            ),
            ChangeNotifierProvider<ThemeProvider>.value(value: themeProvider),
          ],
          child: MaterialApp.router(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('en'),
            routerConfig: router,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
    }

    Future<void> openTab(WidgetTester tester, String label) async {
      await tester.tap(find.widgetWithText(Tab, label));
      await tester.pumpAndSettle();
    }

    testWidgets('no tab for proxy and request settings that are never applied',
        (tester) async {
      await pumpConfig(tester);
      expect(find.widgetWithText(Tab, 'Mesh'), findsNothing);
      expect(find.text('Use Proxy Server'), findsNothing);
      expect(find.text('Max Retries'), findsNothing);
    });

    testWidgets('runtime tab hides unread support provider and timeouts',
        (tester) async {
      await pumpConfig(tester);
      expect(find.text('Preferred Support Provider'), findsNothing);
      expect(find.text('Concurrent Requests'), findsNothing);
      // Auto-restart is read by GatewayControlService, so it stays.
      expect(find.byType(SwitchListTile), findsOneWidget);
    });

    testWidgets('app tab hides security, language and developer controls',
        (tester) async {
      await pumpConfig(tester);
      await openTab(tester, 'App');

      expect(find.text('Encrypt Local Data'), findsNothing);
      expect(find.text('Remember Authentication Tokens'), findsNothing);
      expect(find.text('Language'), findsNothing);
      expect(find.text('Debug Mode'), findsNothing);
      expect(find.text('Enable Notifications'), findsNothing);
      expect(find.byKey(const ValueKey('config-not-available-note')),
          findsOneWidget);
      expect(find.textContaining('Not available yet'), findsOneWidget);
    });

    testWidgets('theme choice applies to ThemeProvider at once',
        (tester) async {
      await pumpConfig(tester);
      await openTab(tester, 'App');

      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Dark').last);
      await tester.pumpAndSettle();

      expect(themeProvider.themeMode, ThemeMode.dark);
    });

    testWidgets('close-to-tray switch writes the setting the window reads',
        (tester) async {
      await pumpConfig(tester);
      await openTab(tester, 'App');

      final tile = find.widgetWithText(
          SwitchListTile, 'Keep running in the tray when closed');
      expect(tile, findsOneWidget);
      await tester.tap(tile);
      await tester.pumpAndSettle();

      expect(await settingsService.isMinimizeToTrayEnabled(), isFalse);
    });

    testWidgets('storage tab hides history and cache size controls',
        (tester) async {
      await pumpConfig(tester);
      await openTab(tester, 'Storage');

      expect(find.text('Data Retention'), findsNothing);
      expect(find.text('Auto-cleanup Old Data'), findsNothing);
      expect(find.text('Enable Response Cache'), findsNothing);
      // Clearing the cache does real, measured work, so it stays.
      expect(find.text('Clear Cache Now'), findsOneWidget);
    });
  });

  group('Theme preference (#854)', () {
    test('theme saved by SettingsPreferenceService is what ThemeProvider loads',
        () async {
      SharedPreferences.setMockInitialValues({});
      await settings.SettingsPreferenceService().setTheme('light');

      final provider = ThemeProvider();
      for (var i = 0; i < 20 && provider.themeMode != ThemeMode.light; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      expect(provider.themeMode, ThemeMode.light);
    });

    test('theme set in ThemeProvider is what the settings service reads',
        () async {
      SharedPreferences.setMockInitialValues({});
      await ThemeProvider(skipLoad: true).setThemeMode(ThemeMode.light);
      expect(await settings.SettingsPreferenceService().getTheme(), 'light');
    });
  });

  group('Window close (#854)', () {
    test('hides to tray by default', () async {
      SharedPreferences.setMockInitialValues({});
      expect(await WindowManagerService().handleWindowClose(), isFalse);
    });

    test('quits when close-to-tray is turned off', () async {
      SharedPreferences.setMockInitialValues({
        'settings_minimize_to_tray': false,
      });
      expect(await WindowManagerService().handleWindowClose(), isTrue);
    });
  });
}
