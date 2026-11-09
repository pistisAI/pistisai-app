import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pistisai/screens/onboarding/steps/connection_method_step.dart';
import 'package:pistisai/services/auth_service.dart';
import 'package:pistisai/services/onboarding/setup_wizard_service.dart';
import 'package:pistisai/services/provider_configuration_manager.dart';
import 'package:pistisai/services/provider_discovery_service.dart';
import 'package:pistisai/services/setup_status_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('connection method step offers Hermes and not OpenClaw',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final service = SetupWizardService(
      _FakeProviderDiscoveryService(),
      _FakeSetupStatusService(),
      _FakeProviderConfigurationManager(),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: ChangeNotifierProvider<SetupWizardService>.value(
          value: service,
          child: const Scaffold(
            body: ConnectionMethodStep(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Hermes Agent'), findsOneWidget);
    expect(find.textContaining('OpenClaw'), findsNothing);

    await tester.tap(find.text('Hermes Agent'));
    await tester.pump();

    expect(service.state.selectedMethod, ConnectionMethod.hermes);
  });
}

class _FakeProviderDiscoveryService extends ProviderDiscoveryService {}

class _FakeProviderConfigurationManager extends ProviderConfigurationManager {}

class _FakeSetupStatusService extends SetupStatusService {
  _FakeSetupStatusService()
      : super(
          authService: _FakeAuthService(),
          storage: InMemorySetupStatusStorage(),
        );
}

class _FakeAuthService extends ChangeNotifier implements AuthService {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
