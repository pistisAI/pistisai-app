import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pistisai/config/theme.dart';
import 'package:pistisai/l10n/app_localizations.dart';
import 'package:pistisai/screens/avatar/avatar_customization_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('Select keeps the colour chosen in the picker', (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(1400, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    // The screen shows a breadcrumb bar that reads the current route.
    final router = GoRouter(
      initialLocation: '/avatar/customize',
      routes: [
        GoRoute(
          path: '/avatar/customize',
          builder: (context, state) => const AvatarCustomizationScreen(),
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
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Custom color selected'), findsNothing);

    await tester.ensureVisible(find.text('Pick Color'));
    await tester.tap(find.text('Pick Color'));
    await tester.pump(const Duration(milliseconds: 400));

    // Move the picker as a user would: report a new colour.
    final picker = tester.widget<ColorPicker>(find.byType(ColorPicker));
    final opened = picker.pickerColor;
    const chosen = Color(0xFF12AB34);
    expect(chosen, isNot(opened));
    picker.onColorChanged(chosen);

    await tester.tap(find.text('Select'));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Custom color selected'), findsOneWidget);

    // Reopening shows the chosen colour, not the one the dialog first had.
    await tester.tap(find.text('Pick Color'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(
      tester.widget<ColorPicker>(find.byType(ColorPicker)).pickerColor,
      chosen,
    );
  });
}
