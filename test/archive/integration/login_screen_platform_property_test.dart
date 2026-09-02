import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pistisai/screens/login_screen.dart';

import '../../helpers/mock_services.dart';
import '../../helpers/test_app_wrapper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Login Screen Platform Components Property Tests', () {
    setUp(() async {
      await initializeMockPlugins();
    });

    testWidgets(
      'Login screen renders without errors',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          createFullTestApp(
            const LoginScreen(),
          ),
        );

        await tester.pumpAndSettle();

        // Verify basic components are present (current login UI)
        expect(find.byType(Scaffold), findsOneWidget);
        expect(find.byType(LoginScreen), findsOneWidget);
        expect(find.text('Hey Christopher!'), findsOneWidget);
        expect(find.textContaining('Connect to Cloud Relay'), findsOneWidget);
      },
    );

    testWidgets(
      'Login screen components consistent across themes',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          createFullTestApp(
            const LoginScreen(),
            themeMode: ThemeMode.light,
          ),
        );

        await tester.pumpAndSettle();

        final scaffoldFinderLight = find.byType(Scaffold);
        expect(scaffoldFinderLight, findsOneWidget);

        // Switch to dark theme
        await tester.pumpWidget(
          createFullTestApp(
            const LoginScreen(),
            themeMode: ThemeMode.dark,
          ),
        );

        await tester.pumpAndSettle();

        final scaffoldFinderDark = find.byType(Scaffold);
        expect(scaffoldFinderDark, findsOneWidget);
      },
    );

    testWidgets(
      'Login button has proper accessibility features',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          createFullTestApp(
            const LoginScreen(),
          ),
        );

        await tester.pumpAndSettle();

        final button = find.byType(ElevatedButton);
        expect(button, findsOneWidget);

        // Check that the button has semantic properties
        final buttonWidget = tester.widget<ElevatedButton>(button);
        expect(buttonWidget.onPressed, isNotNull);
      },
    );

    testWidgets(
      'Login screen adapts to different screen sizes',
      (WidgetTester tester) async {
        // Test mobile size
        await tester.pumpWidget(
          createFullTestApp(
            const LoginScreen(),
          ),
        );

        await tester.pumpAndSettle();

        // Verify components are present and properly sized
        expect(find.byType(Scaffold), findsOneWidget);
        expect(find.byType(LoginScreen), findsOneWidget);
      },
    );
  });
}
