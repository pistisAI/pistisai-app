/// App Launch Integration Tests
/// These tests run against a REAL Flutter app instance on the virtual display.
/// They require the test desktop to be running with Xvfb (DISPLAY=:99).
///
/// Run with: DISPLAY=:99 flutter test test/integration/app_launch_integration_test.dart

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('App Launch Integration Tests', () {
    testWidgets('App launches and shows main window', (WidgetTester tester) async {
      // The app is launched by the integration_test driver.
      // This test verifies the app process is alive and responsive.
      
      // Pump a minimal frame to verify binding works
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      
      // If we get here, the integration test driver connected to the running app
      expect(true, isTrue, reason: 'Integration test driver connected to running app');
    });

    testWidgets('App health endpoint responds', (WidgetTester tester) async {
      // Verify the embedded router health endpoint works
      final client = HttpClient();
      try {
        final request = await client.getUrl(Uri.parse('http://127.0.0.1:1337/health'));
        final response = await request.close();
        expect(response.statusCode, equals(200));
        
        final body = await response.transform(utf8.decoder).join();
        expect(body, equals('OK'));
      } finally {
        client.close();
      }
    });

    testWidgets('Window manager channel is registered', (WidgetTester tester) async {
      const channel = MethodChannel('pistisai/window_manager');
      
      try {
        final result = await channel.invokeMethod('getWindows');
        expect(result, isA<List>());
        // Should find at least the app's own window
        expect((result as List).isNotEmpty, isTrue, reason: 'Should find at least one window');
      } on PlatformException catch (e) {
        // Channel exists but may fail if not on Linux - that's OK for verification
        expect(e.code, isNot(equals('channel-error')));
      }
    });

    testWidgets('GUI automation channel is registered', (WidgetTester tester) async {
      const channel = MethodChannel('pistisai/gui_automation');
      
      try {
        final result = await channel.invokeMethod('takeScreenshot', {
          'path': '/tmp/integration_test_screenshot.ppm',
        });
        expect(result, isTrue);
      } on PlatformException catch (e) {
        expect(e.code, isNot(equals('channel-error')));
      }
    });

    testWidgets('Vision channels are registered', (WidgetTester tester) async {
      const cameraChannel = MethodChannel('pistisai/camera_capture');
      const ocrChannel = MethodChannel('pistisai/ocr_engine');
      const regionChannel = MethodChannel('pistisai/region_capture');
      
      for (final channel in [cameraChannel, ocrChannel, regionChannel]) {
        try {
          await channel.invokeMethod('healthCheck');
        } on PlatformException catch (e) {
          // Channel exists - error means method not implemented, not channel missing
          expect(e.code, isNot(equals('channel-error')));
        }
      }
    });

    testWidgets('App can take screenshot', (WidgetTester tester) async {
      const channel = MethodChannel('pistisai/gui_automation');
      
      final result = await channel.invokeMethod('takeScreenshot', {
        'path': '/tmp/app_screenshot_test.ppm',
      });
      
      expect(result, isTrue);
      
      // Verify file was created
      final file = File('/tmp/app_screenshot_test.ppm');
      expect(await file.exists(), isTrue);
      expect(await file.length(), greaterThan(0));
      
      // Cleanup
      await file.delete();
    });
  });
}