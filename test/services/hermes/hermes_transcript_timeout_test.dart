import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pistisai/models/agent_event.dart';
import 'package:pistisai/services/hermes/hermes_streaming_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('owned session chat', () {
    test('a session that cannot be opened fails with a hub message', () async {
      final client = MockClient((request) async {
        if (request.url.path == '/health' || request.url.path == '/v1/models') {
          return http.Response('{"data":[]}', 200);
        }
        return http.Response('{"error":"no"}', 500);
      });
      final service = HermesStreamingService(client: client);
      try {
        final messages = await service
            .streamResponse(
              prompt: 'hello',
              model: 'hermes-agent',
              conversationId: 'test-conversation',
            )
            .timeout(const Duration(seconds: 8))
            .toList();
        expect(messages.last.hasError, isTrue);
        expect(messages.last.error, contains('could not open a Hermes session'));
        expect(messages.last.error, contains('Check the hub connection'));
        expect(messages.last.error, isNot(contains('Exception')));
      } finally {
        service.dispose();
      }
    });

    test('chat/stream deltas are yielded and the 750 ms poll is not used',
        () async {
      final paths = <String>[];
      final client = MockClient((request) async {
        paths.add('${request.method} ${request.url.path}');
        if (request.url.path == '/health' || request.url.path == '/v1/models') {
          return http.Response('{"data":[]}', 200);
        }
        if (request.method == 'POST' && request.url.path == '/api/sessions') {
          return http.Response(
            '{"session":{"id":"api_1"}}',
            201,
          );
        }
        if (request.url.path == '/api/sessions/api_1/chat/stream') {
          return http.Response(
            'event: assistant.delta\n'
            'data: {"message_id":"m","delta":"Hello from Hermes"}\n'
            '\n'
            'event: tool.started\n'
            'data: {"message_id":"m","tool_name":"read_file"}\n'
            '\n'
            'event: tool.completed\n'
            'data: {"message_id":"m","tool_name":"read_file"}\n'
            '\n'
            'event: assistant.completed\n'
            'data: {"message_id":"m","content":"Hello from Hermes"}\n'
            '\n',
            200,
          );
        }
        return http.Response('no', 404);
      });
      final service = HermesStreamingService(client: client);
      try {
        final events = <Object>[];
        final sub = service.agentEventStream.listen(events.add);
        final messages = await service
            .streamResponse(
              prompt: 'hello',
              model: 'hermes-agent',
              conversationId: 'test-conversation',
            )
            .timeout(const Duration(seconds: 8))
            .toList();
        await Future<void>.delayed(Duration.zero);
        await sub.cancel();
        expect(
          messages.any((m) => m.chunk.contains('Hello from Hermes')),
          isTrue,
        );
        expect(messages.last.isComplete, isTrue);
        expect(paths.any((path) => path.contains('/messages')), isFalse);
        expect(events.whereType<AgentToolStarted>(), isNotEmpty);
      } finally {
        service.dispose();
      }
    });
  });
}
