import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pistisai/services/platform_adapter.dart';
import 'package:pistisai/services/platform_detection_service.dart';

import '../test_config.dart';

void main() {
  group('PlatformAdapter', () {
    late PlatformDetectionService platformService;
    late PlatformAdapter platformAdapter;

    setUp(() {
      TestConfig.initialize();
      platformService = PlatformDetectionService();
      platformAdapter = PlatformAdapter(platformService);
    });

    tearDown(() {
      platformService.dispose();
      TestConfig.cleanup();
    });

    group('Component Building', () {
      testWidgets('should build platform-appropriate button', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: platformAdapter.buildButton(
                onPressed: () {},
                child: const Text('Test Button'),
              ),
            ),
          ),
        );

        expect(find.text('Test Button'), findsOneWidget);
        expect(find.byType(ElevatedButton), findsOneWidget);
      });

      testWidgets('should build platform-appropriate progress indicator', (
        tester,
      ) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(body: platformAdapter.buildProgressIndicator()),
          ),
        );

        expect(find.byType(CircularProgressIndicator), findsOneWidget);
      });

      testWidgets('should build platform-appropriate card', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: platformAdapter.buildCard(
                child: const Text('Card Content'),
              ),
            ),
          ),
        );

        expect(find.text('Card Content'), findsOneWidget);
        expect(find.byType(Card), findsOneWidget);
      });
    });

    group('Button Variants', () {
      testWidgets('should build primary button', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: platformAdapter.buildButton(
                onPressed: () {},
                child: const Text('Primary'),
                isPrimary: true,
              ),
            ),
          ),
        );

        expect(find.byType(ElevatedButton), findsOneWidget);
      });

      testWidgets('should build secondary button', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: platformAdapter.buildButton(
                onPressed: () {},
                child: const Text('Secondary'),
                isPrimary: false,
              ),
            ),
          ),
        );

        expect(find.byType(TextButton), findsOneWidget);
      });
    });

    group('Progress Indicator Variants', () {
      testWidgets('should build determinate progress indicator', (
        tester,
      ) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: platformAdapter.buildProgressIndicator(value: 0.5),
            ),
          ),
        );

        final indicator = tester.widget<CircularProgressIndicator>(
          find.byType(CircularProgressIndicator),
        );
        expect(indicator.value, equals(0.5));
      });

      testWidgets('should build indeterminate progress indicator', (
        tester,
      ) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(body: platformAdapter.buildProgressIndicator()),
          ),
        );

        final indicator = tester.widget<CircularProgressIndicator>(
          find.byType(CircularProgressIndicator),
        );
        expect(indicator.value, isNull);
      });
    });
  });
}
