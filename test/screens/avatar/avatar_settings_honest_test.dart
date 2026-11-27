// Avatar settings: size and glow must reach the chat avatar when saved, and
// colour theme / animation style, which nothing applies yet, are labelled
// "not available yet" instead of being offered (AGENTS.md: "Controls tell
// the truth"). Reset on the customization screen must also reach the chat
// avatar.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pistisai/config/theme.dart';
import 'package:pistisai/di/locator.dart' as di;
import 'package:pistisai/l10n/app_localizations.dart';
import 'package:pistisai/models/avatar/personality_models.dart';
import 'package:pistisai/screens/avatar/avatar_customization_screen.dart';
import 'package:pistisai/screens/avatar/avatar_settings_screen.dart';
import 'package:pistisai/services/avatar/avatar_appearance.dart';
import 'package:pistisai/services/avatar/avatar_state_service.dart';
import 'package:pistisai/services/settings_preference_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeAvatarState extends ChangeNotifier implements AvatarStateService {
  @override
  ExtendedAvatarProfile? get currentProfile => null;
  @override
  String get agentName => 'Agent';
  @override
  String? get error => null;
  @override
  bool get isLoading => false;
  @override
  bool get isReady => true;
  @override
  String get evolutionStage => 'curious_explorer';
  @override
  int get conversationCount => 0;
  @override
  double get depthScore => 0.0;
  @override
  PersonalityTraits get traits => PersonalityTraits.defaultTraits;
  @override
  Future<void> loadProfile() async {}
  @override
  Future<Map<String, dynamic>> getEvolutionRequirements() async =>
      <String, dynamic>{
        'can_evolve': false,
        'deep_conversations': 0,
        'required_deep_conversations': 10,
        'average_novelty': 0.0,
        'required_novelty': 0.5,
      };
  @override
  Future<void> updateAgentName(String name) async {}
  @override
  Future<void> updateTraits(PersonalityTraits traits) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  void register<T extends Object>(T instance) {
    if (di.serviceLocator.isRegistered<T>()) {
      di.serviceLocator.unregister<T>();
    }
    di.serviceLocator.registerSingleton<T>(instance);
  }

  tearDown(() {
    avatarAppearance.value = const AvatarAppearance();
    if (di.serviceLocator.isRegistered<AvatarStateService>()) {
      di.serviceLocator.unregister<AvatarStateService>();
    }
    if (di.serviceLocator.isRegistered<SettingsPreferenceService>()) {
      di.serviceLocator.unregister<SettingsPreferenceService>();
    }
  });

  Future<void> pumpRoute(
      WidgetTester tester, String path, Widget screen) async {
    tester.view.physicalSize = const Size(1400, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final router = GoRouter(
      initialLocation: path,
      routes: [GoRoute(path: path, builder: (context, state) => screen)],
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
  }

  testWidgets('saving size and glow updates the chat avatar right away',
      (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    register<AvatarStateService>(_FakeAvatarState());
    register<SettingsPreferenceService>(SettingsPreferenceService());
    expect(avatarAppearance.value.sizeMultiplier, 1.0);

    await pumpRoute(tester, '/avatar/settings', const AvatarSettingsScreen());

    await tester.ensureVisible(find.text('Large'));
    await tester.tap(find.text('Large'));
    await tester.pump();

    final save = find.text('Save Settings');
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(seconds: 3));

    expect(avatarAppearance.value.sizeMultiplier, 1.3);
  });

  testWidgets('colour theme and animation style are labelled, not offered',
      (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    register<AvatarStateService>(_FakeAvatarState());
    register<SettingsPreferenceService>(SettingsPreferenceService());

    await pumpRoute(tester, '/avatar/settings', const AvatarSettingsScreen());

    expect(find.textContaining('Not available yet'), findsOneWidget);
    for (final selected in ['Personality-Derived', 'Bounce']) {
      final dropdown = tester.widget<DropdownButton<String>>(find.ancestor(
        of: find.text(selected),
        matching: find.byType(DropdownButton<String>),
      ));
      expect(dropdown.onChanged, isNull, reason: selected);
    }
  });

  testWidgets('Reset to defaults also resets the chat avatar', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'avatar_size': 'large',
      'avatar_glow_enabled': false,
    });
    await reloadAvatarAppearance();
    expect(avatarAppearance.value.sizeMultiplier, 1.3);

    await pumpRoute(
        tester, '/avatar/customize', const AvatarCustomizationScreen());

    await tester.tap(find.byTooltip('Reset to defaults'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('Reset').last);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(seconds: 3));

    expect(avatarAppearance.value.sizeMultiplier, 1.0);
    expect(avatarAppearance.value.glowEnabled, isTrue);
  });
}
