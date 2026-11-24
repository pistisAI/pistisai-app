import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pistisai/services/hermes/hermes_streaming_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Pistisai transcript fail-fast (#860)', () {
    test('persistent transcript read errors fail fast with a clear message',
        () async {
      // Health + model discovery succeed so the stream starts; the inbound
      // post succeeds; every transcript read then fails (hub went away).
      final client = MockClient((request) async {
        if (request.url.path == '/health') {
          return http.Response('', 200);
        }
        if (request.url.path == '/v1/models') {
          return http.Response(
            '{"data":[]}',
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        if (request.method == 'POST') {
          return http.Response(
            '{}',
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('hub unavailable', 500);
      });

      final service = HermesStreamingService(
        client: client,
        transcriptFetchTimeout: const Duration(milliseconds: 150),
      );
      try {
        final messages = await service
            .streamResponse(
              prompt: 'hello',
              model: 'hermes-agent',
              conversationId: 'test-conversation',
            )
            .timeout(const Duration(seconds: 8))
            .toList();

        expect(messages, isNotEmpty);
        expect(messages.last.hasError, isTrue);
        expect(messages.last.error, contains('could not read'));
        expect(messages.last.error, contains('Check the hub connection'));
        expect(messages.last.error, isNot(contains('Exception')));
      } finally {
        service.dispose();
      }
    });

    test('a transient read failure recovers and still delivers the reply',
        () async {
      var reads = 0;
      const reply = '{"data":[{"id":"a1","role":"assistant",'
          '"content":"Hello from Hermes","timestamp":1764000000}]}';
      final client = MockClient((request) async {
        if (request.url.path == '/health') return http.Response('', 200);
        if (request.url.path == '/v1/models') {
          return http.Response(
            '{"data":[]}',
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        if (request.method == 'POST') {
          return http.Response(
            '{}',
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        reads += 1;
        if (reads == 2) return http.Response('temporary', 503);
        return http.Response(
          reads == 1 ? '{"data":[]}' : reply,
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final service = HermesStreamingService(
        client: client,
        transcriptFetchTimeout: const Duration(seconds: 5),
      );
      try {
        final messages = await service
            .streamResponse(
              prompt: 'hello',
              model: 'hermes-agent',
              conversationId: 'test-conversation',
            )
            .timeout(const Duration(seconds: 8))
            .toList();

        expect(
          messages.any((m) => m.error?.contains('could not read') ?? false),
          isFalse,
        );
        expect(
            messages.any((m) => m.chunk.contains('Hello from Hermes')), isTrue);
        expect(messages.last.isComplete, isTrue);
      } finally {
        service.dispose();
      }
    });
  });
}
