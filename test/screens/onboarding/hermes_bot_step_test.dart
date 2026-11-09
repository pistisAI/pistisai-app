import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pistisai/screens/onboarding/steps/hermes_bot_step.dart';
import 'package:pistisai/services/auth_service.dart';
import 'package:pistisai/services/hermes/hermes_bot_install_service.dart';
import 'package:pistisai/services/onboarding/setup_wizard_service.dart';
import 'package:pistisai/services/provider_configuration_manager.dart';
import 'package:pistisai/services/provider_discovery_service.dart';
import 'package:pistisai/services/setup_status_service.dart';
import 'package:pistisai/models/provider_configuration.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('initial state shows the description', (tester) async {
    final pending = Completer<HermesBotInstallReport>();
    final installer = _RecordingInstaller(
      const HermesBotInstallReport(<HermesBotInstallStep>[]),
      pending: pending,
    );

    await tester.pumpWidget(
      _host(_wizard(), HermesBotStep(installer: installer)),
    );
    await tester.pump();

    expect(find.textContaining('first-time setup'), findsOneWidget);
    expect(find.textContaining('aigent-watch'), findsOneWidget);
    expect(find.textContaining('drift-scan'), findsOneWidget);
    expect(find.textContaining('6 hours'), findsOneWidget);
    expect(find.textContaining('Windows'), findsOneWidget);
    expect(find.textContaining('Installing PistisAI package'), findsOneWidget);

    pending.complete(const HermesBotInstallReport(<HermesBotInstallStep>[]));
    await tester.pumpAndSettle();
  });

  testWidgets('install success shows all steps installed', (tester) async {
    final installer = _RecordingInstaller(
      HermesBotInstallReport(<HermesBotInstallStep>[
        HermesBotInstallStep(
          name: HermesBotInstallService.agentStep,
          status: HermesBotInstallStatus.installed,
          detail: 'Wrote 2 file(s).',
        ),
        HermesBotInstallStep(
          name: HermesBotInstallService.desktopStep,
          status: HermesBotInstallStatus.installed,
          detail: 'Wrote 1 file(s).',
        ),
        HermesBotInstallStep(
          name: HermesBotInstallService.profileStep,
          status: HermesBotInstallStatus.installed,
          detail: 'Wrote 3 file(s).',
        ),
        HermesBotInstallStep(
          name: HermesBotInstallService.enableStep,
          status: HermesBotInstallStatus.installed,
          detail: 'hermes plugins enable pistisai',
        ),
        HermesBotInstallStep(
          name: HermesBotInstallService.routineStep,
          status: HermesBotInstallStatus.installed,
          detail: 'Created drift-scan every 6h.',
        ),
      ]),
    );

    await tester.pumpWidget(
      _host(_wizard(), HermesBotStep(installer: installer)),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('PistisAI package: Installed'), findsOneWidget);
    expect(find.textContaining('Desktop embed: Installed'), findsOneWidget);
    expect(find.textContaining('aigent-watch profile: Installed'), findsOneWidget);
    expect(find.textContaining('Enable pistisai: Installed'), findsOneWidget);
    expect(find.textContaining('drift-scan routine: Installed'), findsOneWidget);
    expect(find.textContaining('Install complete'), findsOneWidget);
    expect(find.text('Retry'), findsNothing);
    expect(installer.calls, 1);
  });

  testWidgets('install failure shows the failed step and retry button',
      (tester) async {
    final installer = _RecordingInstaller(
      HermesBotInstallReport(<HermesBotInstallStep>[
        HermesBotInstallStep(
          name: HermesBotInstallService.agentStep,
          status: HermesBotInstallStatus.installed,
          detail: 'Wrote 2 file(s).',
        ),
        HermesBotInstallStep(
          name: HermesBotInstallService.enableStep,
          status: HermesBotInstallStatus.failed,
          detail: 'hermes missing',
        ),
      ]),
    );

    await tester.pumpWidget(
      _host(_wizard(), HermesBotStep(installer: installer)),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Enable pistisai: Failed'), findsOneWidget);
    expect(find.textContaining('hermes missing'), findsOneWidget);
    expect(find.textContaining('Install failed: Enable pistisai'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets('retry re-calls install', (tester) async {
    final installer = _RecordingInstaller(
      const HermesBotInstallReport(<HermesBotInstallStep>[
        HermesBotInstallStep(
          name: HermesBotInstallService.enableStep,
          status: HermesBotInstallStatus.failed,
          detail: 'hermes missing',
        ),
      ]),
    );

    await tester.pumpWidget(
      _host(_wizard(), HermesBotStep(installer: installer)),
    );
    await tester.pumpAndSettle();
    expect(installer.calls, 1);

    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    expect(installer.calls, 2);
  });
}

SetupWizardService _wizard() {
  return SetupWizardService(
    _FakeProviderDiscoveryService(),
    _FakeSetupStatusService(),
    _FakeProviderConfigurationManager(),
  );
}

Widget _host(SetupWizardService service, Widget child) {
  return MaterialApp(
    home: ChangeNotifierProvider<SetupWizardService>.value(
      value: service,
      child: Scaffold(body: child),
    ),
  );
}

class _RecordingInstaller extends HermesBotInstallService {
  _RecordingInstaller(this.report, {this.pending});

  final HermesBotInstallReport report;
  final Completer<HermesBotInstallReport>? pending;
  int calls = 0;

  @override
  Future<HermesBotInstallReport> install({int? agentPort}) async {
    calls++;
    final gate = pending;
    if (gate != null && !gate.isCompleted) {
      return gate.future;
    }
    return report;
  }
}

class _FakeProviderDiscoveryService extends ProviderDiscoveryService {}

class _FakeProviderConfigurationManager extends ProviderConfigurationManager {
  @override
  Future<void> saveProvider({
    required String name,
    required ProviderType type,
    required String url,
    required bool isLocal,
    bool isDefault = false,
    String? version,
    ProviderRole? role,
  }) async {}
}

class _FakeSetupStatusService extends SetupStatusService {
  _FakeSetupStatusService()
      : super(
          authService: _FakeAuthService(),
          storage: InMemorySetupStatusStorage(),
        );

  @override
  Future<void> markSetupComplete(String userId) async {}
}

class _FakeAuthService extends ChangeNotifier implements AuthService {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
