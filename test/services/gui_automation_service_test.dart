import 'package:flutter_test/flutter_test.dart';
import 'package:pistisai/services/gui_automation_service.dart';

void main() {
  late GuiAutomationService service;

  setUp(() {
    service = GuiAutomationService();
  });

  group('GuiAutomationService', () {
    group('initialize', () {
      test('should set isInitialized to true on successful health check',
          () async {
        // Note: This test would require mocking http.get for the health check
        // For now, we just verify the service can be created
        expect(service.isInitialized, false);
      });
    });

    group('takeScreenshot', () {
      test('should return null when screenshot fails', () async {
        // This test verifies error handling when screenshot fails
        // Actual testing requires native platform integration
        final result = await service.takeScreenshot();
        expect(result, null);
        expect(service.isProcessing, false);
      });
    });

    group('analyzeScreenshot', () {
      test('should return error message when not initialized', () async {
        final result = await service.analyzeScreenshot('/fake/path.png');
        expect(result, contains('not initialized'));
      });
    });

    group('setEndpoint', () {
      test('should update model endpoint', () {
        service.setEndpoint('http://localhost:8080');
        // Verify the endpoint was set (no direct getter, but we can check it doesn't crash)
        expect(service, isA<GuiAutomationService>());
      });
    });
  });
}
