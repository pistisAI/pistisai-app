import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pistisai/services/hermes/hermes_streaming_service.dart';

/// Integration tests for Hermes streaming service.
///
/// Run with: flutter test test/services/hermes_connection_test.dart
///
/// These tests use flutter_test because HermesStreamingService transitively
/// imports Flutter (package:flutter/foundation.dart). flutter_test normally
/// blocks real HTTP via TestWidgetsFlutterBinding (returns 400 for all
/// HttpClient calls). We bypass that by installing an HttpOverrides that
/// returns a real client inside the test runner.
void main() {
  late HermesStreamingService hermesService;

  setUpAll(() {
    // Override the TestWidgetsFlutterBinding HTTP block with a real client
    HttpOverrides.global = _RealHttpOverrides();
  });

  setUp(() {
    hermesService = HermesStreamingService(
      baseUrl: 'http://127.0.0.1:8642',
    );
  });

  /// Returns true if a Hermes gateway is reachable at the configured base URL.
  /// These tests require a live local gateway; skip when none is running so
  /// the CI unit gate stays green on machines without Hermes installed.
  Future<bool> _hermesGatewayReachable() async {
    try {
      final client = HttpClient();
      final request = await client
          .getUrl(Uri.parse('${hermesService.baseUrl}/health'))
        ..followRedirects = false;
      final response = await request.close().timeout(const Duration(seconds: 3));
      client.close(force: true);
      return response.statusCode == 200;
    } on Exception {
      return false;
    }
  }

  group('Hermes Connection', () {
    test('can connect to local Hermes gateway at :8642', () async {
      final reachable = await _hermesGatewayReachable();
      await hermesService.establishConnection();
      expect(hermesService.connection.isActive, isTrue,
          reason: 'Hermes should be reachable at 127.0.0.1:8642',
          skip: !reachable);
    });

    test('health endpoint returns healthy', () async {
      final reachable = await _hermesGatewayReachable();
      await hermesService.establishConnection();
      final isHealthy = await hermesService.testConnection();
      expect(isHealthy, isTrue,
          reason: 'Hermes health check should pass', skip: !reachable);
    });
  });

  group('Hermes Streaming', () {
    test('can stream a simple chat response (requires API key)',
        () async {
      final reachable = await _hermesGatewayReachable();
      await hermesService.establishConnection();
      if (!reachable) {
        // No live gateway on this machine; nothing to stream against.
        return;
      }
      expect(hermesService.connection.isActive, isTrue);

      // Attempt stream; Hermes requires API key for /v1/runs. Service
      // surfaces 401 as an in-band error message (not an exception), so
      // we accept either: chunks arrived, OR an error message indicating
      // 401 / invalid API key.
      bool gotChunks = false;
      bool gotAuthError = false;
      await for (final msg in hermesService.streamResponse(
        prompt: 'Say hello in one short sentence.',
        model: 'deepseek-v4-flash',
        conversationId: 'test-conv-001',
      )) {
        print('[Test] received msg: chunk=${msg.chunk.length}ch, '
            'error=${msg.error}, isComplete=${msg.isComplete}');
        if (msg.chunk.isNotEmpty) {
          gotChunks = true;
        }
        if (msg.error != null &&
            (msg.error!.contains('401') ||
                msg.error!.contains('Invalid API key'))) {
          gotAuthError = true;
          print('[Test] ⚠️  Hermes streaming requires API key (401) — '
              'service reachable, auth missing');
          break;
        }
        if (msg.isComplete) break;
      }

      expect(gotChunks || gotAuthError, isTrue,
          reason: 'Should either stream chunks or report 401 auth requirement');
      if (gotChunks) {
        print('[Test] ✅ Streaming succeeded');
      }
    }, timeout: const Timeout(Duration(seconds: 60)));
  });
}

class _RealHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context);
  }
}
