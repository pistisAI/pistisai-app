// Tray daemon settings must not claim to save or restart anything: no service
// stores or applies these settings yet, so the controls are disabled under a
// "not available yet" note (AGENTS.md: "Controls tell the truth").
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pistisai/config/theme.dart';
import 'package:pistisai/l10n/app_localizations.dart';
import 'package:pistisai/screens/settings/daemon_settings_screen.dart';
import 'package:pistisai/services/platform_adapter.dart';
import 'package:pistisai/services/platform_detection_service.dart';
import 'package:pistisai/services/unified_connection_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('tray settings are disabled and offer no fake save or restart',
      (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    tester.view.physicalSize = const Size(1400, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final router = GoRouter(
      initialLocation: '/settings/daemon',
      routes: [
        GoRoute(
          path: '/settings/daemon',
          builder: (context, state) => const DaemonSettingsScreen(),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(MultiProvider(
      providers: [
        Provider<PlatformAdapter>.value(
          value: PlatformAdapter(PlatformDetectionService()),
        ),
        ChangeNotifierProvider<UnifiedConnectionService>(
          create: (_) => UnifiedConnectionService(),
        ),
      ],
      child: MaterialApp.router(
        theme: AppTheme.darkTheme,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        routerConfig: router,
      ),
    ));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));

    // The real connection status is still shown.
    expect(find.text('Real-time Connection Status'), findsOneWidget);

    // No button reports a save or restart that never happens.
    expect(find.text('Save Settings'), findsNothing);
    expect(find.text('Restart Daemon'), findsNothing);
    expect(find.textContaining('saved successfully'), findsNothing);

    // The settings are labelled and cannot be changed.
    expect(find.textContaining('Not available yet'), findsOneWidget);
    final switches = tester.widgetList<Switch>(find.byType(Switch));
    expect(switches, isNotEmpty);
    for (final s in switches) {
      expect(s.onChanged, isNull);
    }
    final sliders = tester.widgetList<Slider>(find.byType(Slider));
    expect(sliders, isNotEmpty);
    for (final s in sliders) {
      expect(s.onChanged, isNull);
    }
    final dropdown = tester
        .widget<DropdownButton<String>>(find.byType(DropdownButton<String>));
    expect(dropdown.onChanged, isNull);
  });
}
