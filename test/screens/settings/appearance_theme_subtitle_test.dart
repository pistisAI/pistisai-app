import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pistisai/config/theme.dart';
import 'package:pistisai/l10n/app_localizations.dart';
import 'package:pistisai/screens/settings/appearance_settings_screen.dart';
import 'package:pistisai/services/theme_provider.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('theme mode subtitle shows System for system mode',
      (tester) async {
    final router = GoRouter(
      initialLocation: '/config/appearance',
      routes: [
        GoRoute(
          path: '/config/appearance',
          builder: (context, state) =>
              ChangeNotifierProvider<ThemeProvider>.value(
            value: ThemeProvider(skipLoad: true),
            child: const AppearanceSettingsScreen(),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(MaterialApp.router(
      theme: AppTheme.darkTheme,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
      routerConfig: router,
    ));
    await tester.pump(const Duration(milliseconds: 200));

    final themeTile = tester.widget<ListTile>(find.byWidgetPredicate((w) =>
        w is ListTile &&
        w.leading is Icon &&
        (w.leading as Icon).icon == Icons.light_mode));
    expect((themeTile.subtitle as Text).data, 'System');
  });
}
