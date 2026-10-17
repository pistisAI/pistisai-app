import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pistisai/screens/onboarding/steps/completion_step.dart';
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

  testWidgets('the first-time step describes the package install',
      (tester) async {
    final service = SetupWizardService(
      _FakeProviderDiscoveryService(),
      _FakeSetupStatusService(),
      _FakeProviderConfigurationManager(),
    );

    await tester.pumpWidget(_host(service, const HermesBotStep()));
    await tester.pumpAndSettle();

    expect(find.textContaining('first-time setup'), findsOneWidget);
    expect(find.textContaining('aigent-watch'), findsOneWidget);
    expect(find.textContaining('drift-scan'), findsOneWidget);
    expect(find.textContaining('6 hours'), findsOneWidget);
    expect(find.textContaining('Windows'), findsOneWidget);
    expect(find.byType(SwitchListTile), findsNothing);
  });

  testWidgets('completion lists each install step status', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 2000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final installer = _RecordingInstaller(
      const HermesBotInstallReport(<HermesBotInstallStep>[
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
    final service = SetupWizardService(
      _FakeProviderDiscoveryService(),
      _FakeSetupStatusService(),
      _FakeProviderConfigurationManager(),
      botInstaller: installer,
    );
    service.selectConnectionMethod(ConnectionMethod.hermes);
    service.selectHermesLocation(HermesLocation.local);
    service.setHermesUrl('http://127.0.0.1:8642');
    service.selectProvider(const ProviderInfo(
      id: 'hermes_runtime',
      name: 'Hermes Agent',
      type: ProviderType.hermes,
      url: 'http://127.0.0.1:8642',
      isLocal: true,
      isAvailable: true,
      role: ProviderRole.agentRuntime,
    ));

    expect(await service.completeSetup(), isTrue);

    await tester.pumpWidget(_host(service, const CompletionStep()));
    await tester.pumpAndSettle();

    expect(find.textContaining('PistisAI package: Installed'), findsOneWidget);
    expect(find.textContaining('Enable pistisai: Failed'), findsOneWidget);
  });
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
  _RecordingInstaller(this.report);

  final HermesBotInstallReport report;

  int? port;

  @override
  Future<HermesBotInstallReport> install({int? agentPort}) async {
    port = agentPort;
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
