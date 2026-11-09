import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pistisai/screens/onboarding/mobile_connection_screen.dart';
import 'package:pistisai/services/onboarding/mobile_connection_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// USB / on-device smoke + optional Tailscale self-hosted hub probe.
///
/// Run: `bash scripts/test-android-phone.sh`
/// Self-hosted hub: `PISTISAI_SELF_TEST_HUB_HOST=pc.tailnet.ts.net bash scripts/test-android-phone.sh`
const _selfTestHubHost = String.fromEnvironment('PISTISAI_SELF_TEST_HUB_HOST');

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('shows mobile connection screen on device', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final service = MobileConnectionService();
    await tester.pumpWidget(
      ChangeNotifierProvider<MobileConnectionService>.value(
        value: service,
        child: const MaterialApp(home: MobileConnectionScreen()),
      ),
    );
    await tester.pumpAndSettle(const Duration(seconds: 5));

    expect(find.text('Connect this phone'), findsOneWidget);
    expect(find.text('Self-Hosted via Tailscale'), findsOneWidget);
    expect(find.text('Connected via pistisai.app'), findsOneWidget);
  });

  if (_selfTestHubHost.isNotEmpty) {
    testWidgets('probes desktop hub over Tailscale', (tester) async {
      final service = MobileConnectionService();
      final result = await service.probeHub(_selfTestHubHost);
      expect(
        result.success,
        isTrue,
        reason: result.message,
      );
    });
  }
}
