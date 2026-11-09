import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pistisai/brand/brand.dart';
import 'package:pistisai/screens/onboarding/mobile_connection_screen.dart';
import 'package:pistisai/services/onboarding/mobile_connection_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('mobile connection screen offers Tailscale and the brand domain',
      (tester) async {
    final domain = Brand.current.websiteDomain;
    final service = MobileConnectionService();
    await tester.pumpWidget(
      ChangeNotifierProvider<MobileConnectionService>.value(
        value: service,
        child: const MaterialApp(
          home: MobileConnectionScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Connect this phone'), findsOneWidget);
    expect(find.text('Self-Hosted via Tailscale'), findsOneWidget);
    expect(find.text('Connected via $domain'), findsOneWidget);
    expect(find.textContaining('OpenClaw'), findsNothing);
    expect(find.textContaining('pistisai'), findsNothing);

    await tester.tap(find.text('Self-Hosted via Tailscale'));
    await tester.pump();
    expect(find.text('Connect to desktop hub'), findsOneWidget);

    await tester.tap(find.text('Connected via $domain'));
    await tester.pump();
    expect(find.text('Continue with $domain'), findsOneWidget);
  });
}
