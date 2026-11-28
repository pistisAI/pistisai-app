// Issue #853: "Re-run setup wizard" must really reset the setup state and
// land on the wizard, even for a signed-in desktop session that previously
// finished or deferred setup.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pistisai/config/router_redirect.dart';
import 'package:pistisai/config/theme.dart';
import 'package:pistisai/l10n/app_localizations.dart';
import 'package:pistisai/models/user_model.dart';
import 'package:pistisai/screens/settings/connection_settings_screen.dart';
import 'package:pistisai/services/auth_service.dart';
import 'package:pistisai/services/onboarding/setup_wizard_service.dart';
import 'package:pistisai/services/provider_configuration_manager.dart';
import 'package:pistisai/services/provider_discovery_service.dart';
import 'package:pistisai/services/settings_preference_service.dart';
import 'package:pistisai/services/setup_status_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeAuthService extends ChangeNotifier implements AuthService {
  @override
  UserModel? get currentUser => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets('Re-run setup wizard resets setup state and opens the wizard',
      (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final auth = _FakeAuthService();
    final setupStatus = SetupStatusService(
      authService: auth,
      storage: InMemorySetupStatusStorage(),
    );
    final wizard = SetupWizardService(
      ProviderDiscoveryService(),
      setupStatus,
      ProviderConfigurationManager(),
      settings: SettingsPreferenceService(),
    );

    // A user who finished setup once, then also chose "set up later", and
    // whose wizard state is left on a later step.
    await setupStatus.markSetupComplete('local_user');
    await wizard.deferSetup();
    wizard.goToStep(1);
    expect(await wizard.shouldShowWizard(), isFalse);

    final router = GoRouter(
      initialLocation: '/settings/connection',
      redirect: (context, state) async {
        final due = await wizard.shouldShowWizard();
        return resolveAppRedirect(RouterRedirectInput(
          location: state.matchedLocation,
          isAuthenticated: true,
          isAuthLoading: false,
          isWeb: false,
          isMobile: false,
          isAppSubdomain: false,
          isMarketingPath: false,
          hasCallbackParams: false,
          shouldShowDesktopWizard: due,
          shouldShowMobileConnection: false,
          requireCloudLogin: false,
        ));
      },
      routes: [
        GoRoute(
          path: '/settings/connection',
          builder: (context, state) => const ConnectionSettingsScreen(),
        ),
        GoRoute(
          path: '/setup',
          builder: (context, state) => const Text('WIZARD_ROUTE'),
        ),
        GoRoute(
          path: '/chat',
          builder: (context, state) => const Text('CHAT_ROUTE'),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthService>.value(value: auth),
        ChangeNotifierProvider<SetupStatusService>.value(value: setupStatus),
        ChangeNotifierProvider<SetupWizardService>.value(value: wizard),
      ],
      child: MaterialApp.router(
        theme: AppTheme.darkTheme,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        routerConfig: router,
      ),
    ));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Re-run Setup Wizard'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Re-run Setup Wizard'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Clear & Re-run'));
    await tester.pumpAndSettle();

    expect(find.text('WIZARD_ROUTE'), findsOneWidget);
    expect(find.text('CHAT_ROUTE'), findsNothing);
    expect(wizard.isSetupCompleted, isFalse);
    expect(wizard.state.currentStep, 0);
    expect(await SettingsPreferenceService().isSetupWizardDeferred(), isFalse);
    expect(await setupStatus.hasCompletedSetup('local_user'), isFalse);
    expect(await wizard.shouldShowWizard(), isTrue);
  });

  testWidgets('Remote hub access toggle is opt-in and explains the restart',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final auth = _FakeAuthService();
    final setupStatus = SetupStatusService(
      authService: auth,
      storage: InMemorySetupStatusStorage(),
    );
    final wizard = SetupWizardService(
      ProviderDiscoveryService(),
      setupStatus,
      ProviderConfigurationManager(),
      settings: SettingsPreferenceService(),
    );
    final router = GoRouter(
      initialLocation: '/settings/connection',
      routes: [
        GoRoute(
          path: '/settings/connection',
          builder: (context, state) => const ConnectionSettingsScreen(),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthService>.value(value: auth),
        ChangeNotifierProvider<SetupStatusService>.value(value: setupStatus),
        ChangeNotifierProvider<SetupWizardService>.value(value: wizard),
      ],
      child: MaterialApp.router(
        theme: AppTheme.darkTheme,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        routerConfig: router,
      ),
    ));
    await tester.pumpAndSettle();

    final toggle = find.byKey(const Key('remoteHubAccessToggle'));
    expect(toggle, findsOneWidget);
    expect(tester.widget<SwitchListTile>(toggle).value, isFalse);
    expect(
      find.textContaining('Applies after a restart'),
      findsOneWidget,
    );

    await tester.tap(
      find.descendant(of: toggle, matching: find.byType(Switch)),
    );
    await tester.pumpAndSettle();
    expect(
      await SettingsPreferenceService().isRemoteHubAccessEnabled(),
      isTrue,
    );
  });
}
