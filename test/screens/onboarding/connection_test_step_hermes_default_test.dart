import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pistisai/config/app_config.dart';
import 'package:pistisai/l10n/app_localizations.dart';
import 'package:pistisai/models/provider_configuration.dart';
import 'package:pistisai/screens/onboarding/steps/connection_test_step.dart';
import 'package:pistisai/services/auth_service.dart';
import 'package:pistisai/services/onboarding/setup_wizard_service.dart';
import 'package:pistisai/services/provider_configuration_manager.dart';
import 'package:pistisai/services/provider_discovery_service.dart';
import 'package:pistisai/services/setup_status_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// #1042: with no Hermes, custom or provider URL, the connection test must
/// probe the Hermes API default, never the OpenClaw Gateway port 18789.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('connection test with no URL probes the Hermes default',
      (tester) async {
    final wizard = _RecordingWizard();

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: ChangeNotifierProvider<SetupWizardService>.value(
          value: wizard,
          child: const Scaffold(body: ConnectionTestStep()),
        ),
      ),
    );
    await tester.pump();

    expect(wizard.testedUrls, [AppConfig.defaultHermesUrl]);
    expect(wizard.testedUrls.single, isNot(contains('18789')));
  });
}

class _RecordingWizard extends SetupWizardService {
  _RecordingWizard()
      : super(
          _FakeProviderDiscoveryService(),
          _FakeSetupStatusService(),
          _FakeProviderConfigurationManager(),
        );

  final List<String> testedUrls = <String>[];

  @override
  Future<ConnectionTestResult?> testConnection(String url) async {
    testedUrls.add(url);
    return null;
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
