import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pistisai/l10n/app_localizations.dart';
import 'package:pistisai/screens/onboarding/steps/welcome_step.dart';
import 'package:pistisai/screens/onboarding/widgets/local_model_capability_card.dart';
import 'package:pistisai/services/hardware/hardware_capability_service.dart';

const int _gib = LocalModelThresholds.bytesPerGiB;

class _FixedService extends HardwareCapabilityService {
  _FixedService(this._future) : super(useDefaultProbe: false);

  _FixedService.value(LocalModelCapabilityResult result)
      : this(Future.value(result));

  final Future<LocalModelCapabilityResult> _future;

  @override
  Future<LocalModelCapabilityResult> check() => _future;
}

Widget _app(Widget child, {Locale locale = const Locale('en')}) => MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: SingleChildScrollView(child: child)),
    );

LocalModelCapabilityResult _evaluate(double totalGiB,
        {List<String> providers = const []}) =>
    evaluateLocalModelCapability(
      snapshot: HardwareSnapshot(
        architecture: 'x86_64',
        totalMemoryBytes: (totalGiB * _gib).round(),
      ),
      localProviderNames: providers,
    );

void main() {
  testWidgets('shows a checking line until the answer arrives', (tester) async {
    final pending = Completer<LocalModelCapabilityResult>();
    await tester.pumpWidget(
      _app(LocalModelCapabilityCard(service: _FixedService(pending.future))),
    );
    expect(find.byKey(const Key('local_model_capability_checking')),
        findsOneWidget);

    pending.complete(_evaluate(32));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('local_model_capability_sufficient')),
        findsOneWidget);
  });

  testWidgets('sufficient names the detected memory', (tester) async {
    await tester.pumpWidget(_app(LocalModelCapabilityCard(
      service: _FixedService.value(_evaluate(32)),
    )));
    await tester.pumpAndSettle();
    expect(find.text('This computer can host a local model'), findsOneWidget);
    expect(find.textContaining('Detected 32.0 GB of memory (x86_64)'),
        findsOneWidget);
  });

  testWidgets('insufficient offers a provided local machine, not the cloud',
      (tester) async {
    await tester.pumpWidget(_app(LocalModelCapabilityCard(
      service: _FixedService.value(_evaluate(12)),
    )));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('local_model_capability_insufficient')),
        findsOneWidget);
    expect(find.textContaining('a local machine we provide'), findsOneWidget);
    expect(find.textContaining('Below 16 GB'), findsOneWidget);
    expect(find.textContaining(RegExp('cloud', caseSensitive: false)),
        findsNothing);
  });

  testWidgets('middle zone with a running provider is sufficient',
      (tester) async {
    await tester.pumpWidget(_app(LocalModelCapabilityCard(
      service: _FixedService.value(_evaluate(12, providers: ['Ollama'])),
    )));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('local_model_capability_sufficient')),
        findsOneWidget);
    expect(find.textContaining('running local model provider: Ollama'),
        findsOneWidget);
  });

  testWidgets('unknown states the guideline without claiming support',
      (tester) async {
    await tester.pumpWidget(_app(LocalModelCapabilityCard(
      service:
          _FixedService.value(LocalModelCapabilityResult.unsupportedPlatform),
    )));
    await tester.pumpAndSettle();
    expect(find.text('Hardware check not available'), findsOneWidget);
    expect(find.textContaining('needs about 16 GB of memory'), findsOneWidget);
    expect(
        find.textContaining('not available on this platform'), findsOneWidget);
  });

  testWidgets('French copy for the insufficient state', (tester) async {
    await tester.pumpWidget(_app(
      LocalModelCapabilityCard(service: _FixedService.value(_evaluate(4))),
      locale: const Locale('fr'),
    ));
    await tester.pumpAndSettle();
    expect(
      find.text(
          "Cet ordinateur n'a peut-être pas le matériel nécessaire pour un modèle local"),
      findsOneWidget,
    );
    expect(find.textContaining('une machine locale que nous fournissons'),
        findsOneWidget);
    expect(find.textContaining('Mémoire détectée : 4.0 Go'), findsOneWidget);
  });

  testWidgets('WelcomeStep shows the check when the wizard passes a service',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: Scaffold(
        body: SizedBox(
          height: 900,
          width: 1280,
          child: WelcomeStep(
            capabilityService: _FixedService.value(_evaluate(32)),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.byType(LocalModelCapabilityCard), findsOneWidget);
    expect(find.text('This computer can host a local model'), findsOneWidget);
  });

  testWidgets('WelcomeStep without a service shows no hardware claim',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: Scaffold(body: WelcomeStep()),
    ));
    await tester.pumpAndSettle();
    expect(find.byType(LocalModelCapabilityCard), findsNothing);
  });

  test('download copy uses the threshold constant and a provided machine', () {
    final en = lookupAppLocalizations(const Locale('en'));
    final text = en.downloadLocalModelRequirement(
      LocalModelThresholds.recommendedTotalMemoryGiB,
    );
    expect(text, contains('16 GB'));
    expect(text, contains('a local machine we provide'));
    expect(text.toLowerCase(), isNot(contains('no special hardware')));
    final fr = lookupAppLocalizations(const Locale('fr'));
    expect(
      fr.downloadLocalModelRequirement(16),
      contains('une machine locale que nous fournissons'),
    );
  });
}
