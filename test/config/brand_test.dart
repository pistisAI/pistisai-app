import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pistisai/brand/brand.dart';
import 'package:pistisai/brand/brand_config.dart';
import 'package:pistisai/brand/brand_copy.dart';
import 'package:pistisai/brand/brand_localizations.dart';
import 'package:pistisai/brand/brand_yaml.dart';
import 'package:pistisai/components/welcome_screen.dart';
import 'package:pistisai/config/theme.dart';
import 'package:pistisai/config/theme_config.dart';
import 'package:pistisai/screens/onboarding/steps/welcome_step.dart';
import 'package:pistisai/screens/settings/about_settings_screen.dart';

import '../../tool/brand_emit.dart';

void main() {
  final pistisai = _load('pistisai');
  final example = _load('example');

  tearDown(() {
    Brand.debugOverride(null);
  });

  test('default brand file is the Pistisai product', () {
    expect(pistisai.productName, 'Pistisai');
    expect(pistisai.packageTitle, 'PistisAI package');
    expect(pistisai.primaryArgb, 0xFFFFD700);
    expect(pistisai.backgroundArgb, 0xFF181A20);
    expect(pistisai.lockLocale, isFalse);
    expect(pistisai.websiteUrl, 'https://pistisai.app');
  });

  test('baked brand matches brand/pistisai/brand.yaml', () {
    expect(Brand.current.id, pistisai.id);
    expect(Brand.current.productName, pistisai.productName);
    expect(Brand.current.windowTitle, pistisai.windowTitle);
    expect(Brand.current.primaryArgb, pistisai.primaryArgb);
    expect(Brand.current.legalLine, pistisai.legalLine);
    expect(Brand.current.aboutText, pistisai.aboutText);
  });

  testWidgets('default brand renders the Pistisai name', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: const WelcomeStep(),
      ),
    );

    expect(find.text('Welcome to Pistisai'), findsOneWidget);
    expect(find.textContaining('Pistisai'), findsWidgets);
  });

  testWidgets('default about copy names Pistisai', (tester) async {
    await _pumpAbout(tester);
    final visible = _visibleText(tester);
    expect(visible, contains('Pistisai'));
    expect(visible, contains('About Pistisai'));
  });

  test('example brand copy does not contain the upstream product name', () {
    Brand.debugOverride(example);
    for (final sample in BrandCopy.routedSamples()) {
      expect(
        sample.toLowerCase().contains('pistisai'),
        isFalse,
        reason: sample,
      );
    }
    expect(example.defaultLocale, 'fr');
    expect(example.lockLocale, isTrue);
    expect(example.materialLocale, const Locale('fr'));
  });

  testWidgets('non-default brand does not render Pistisai', (tester) async {
    Brand.debugOverride(example);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: const WelcomeStep(),
      ),
    );
    expect(_visibleText(tester).toLowerCase().contains('pistisai'), isFalse);
    expect(find.text('Welcome to Example'), findsOneWidget);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: WelcomeScreen(onNewChat: () {}),
      ),
    );
    expect(_visibleText(tester).toLowerCase().contains('pistisai'), isFalse);
    expect(find.text('Example'), findsOneWidget);

    await _pumpAbout(tester);
    final about = _visibleText(tester);
    expect(about.toLowerCase().contains('pistisai'), isFalse);
    expect(about, contains('About Example'));
    expect(about, contains(example.aboutText));
  });

  test('example theme primary comes from the brand file', () {
    Brand.debugOverride(example);
    final theme = ThemeConfig.loadThemeConfiguration(ThemeMode.dark, null);
    expect(theme.colorScheme.primary, example.primary);
    expect(theme.colorScheme.primary, isNot(const Color(0xFFFFD700)));
  });

  test('default theme primary stays Pistis gold', () {
    final theme = ThemeConfig.loadThemeConfiguration(ThemeMode.dark, null);
    expect(theme.colorScheme.primary, const Color(0xFFFFD700));
    expect(ThemeConfig.primaryColor, const Color(0xFFFFD700));
  });

  testWidgets('locked French example brand renders a Material screen', (
    tester,
  ) async {
    expect(example.lockLocale, isTrue);
    expect(example.materialLocale, const Locale('fr'));
    Brand.debugOverride(example);

    await tester.pumpWidget(
      MaterialApp(
        locale: example.materialLocale,
        localizationsDelegates: brandLocalizationsDelegates,
        supportedLocales: lockedBrandLocales(example),
        home: Scaffold(
          appBar: AppBar(title: Text(example.productName)),
          body: Builder(
            builder: (context) {
              MaterialLocalizations.of(context);
              return const Text('ready');
            },
          ),
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('Example'), findsOneWidget);
    expect(find.text('ready'), findsOneWidget);
    expect(lockedBrandLocales(example), contains(const Locale('fr')));
    expect(lockedBrandLocales(example), contains(const Locale('en')));
  });

  test('launch instructions name the binaries the build still emits', () {
    Brand.debugOverride(example);
    expect(BrandCopy.exeDoubleClick, contains(BrandCopy.shippedWindowsExe));
    expect(
        BrandCopy.exeDoubleClick.toLowerCase(), isNot(contains('example.exe')));
    expect(BrandCopy.shippedLinuxBinary, 'pistisai');
    expect(BrandCopy.landingNarrative.toLowerCase(), isNot(contains('pistis')));
  });

  test('unlocked default brand does not force a locale', () {
    expect(pistisai.lockLocale, isFalse);
    expect(pistisai.materialLocale, isNull);
  });

  test(
      'linux window-title header follows the brand and keeps the binary id out',
      () {
    final header = renderLinuxHeader(example);
    expect(header, contains('BRAND_WINDOW_TITLE "Example"'));
    expect(header.toLowerCase().contains('pistisai'), isFalse);
    final pistisaiHeader = renderLinuxHeader(pistisai);
    expect(pistisaiHeader, contains('BRAND_WINDOW_TITLE "Pistisai"'));
  });
}

BrandConfig _load(String id) {
  final file = File('brand/$id/brand.yaml');
  return parseBrandYaml(file.readAsStringSync());
}

Future<void> _pumpAbout(WidgetTester tester) async {
  final router = GoRouter(
    initialLocation: '/settings/about',
    routes: [
      GoRoute(
        path: '/settings/about',
        builder: (context, state) => const AboutSettingsScreen(),
      ),
      GoRoute(
        path: '/config',
        builder: (context, state) => const SizedBox.shrink(),
      ),
    ],
  );
  await tester.pumpWidget(
    MaterialApp.router(
      theme: AppTheme.darkTheme,
      routerConfig: router,
    ),
  );
  await tester.pumpAndSettle();
}

String _visibleText(WidgetTester tester) {
  final buffer = StringBuffer();
  for (final widget in tester.allWidgets) {
    if (widget is Text) {
      buffer.writeln(widget.data ?? '');
      final span = widget.textSpan;
      if (span != null) {
        buffer.writeln(span.toPlainText());
      }
    }
  }
  return buffer.toString();
}
