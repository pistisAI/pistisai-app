import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pistisai/services/agent_runtime/agent_runtime_client.dart';
import 'package:pistisai/services/agent_runtime/hermes_runtime_client.dart';
import 'package:pistisai/services/hermes/hermes_streaming_service.dart';
import 'package:pistisai/services/providers/base_provider.dart';
import 'package:pistisai/services/providers/hermes_adapter.dart';

/// Live tests against a local Hermes gateway at 127.0.0.1:8642.
///
/// Skip when no gateway is running so CI stays green without Hermes.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = _RealHttpOverrides();

  late String? apiKey;

  setUpAll(() {
    apiKey = _discoverHermesApiKey();
  });

  Future<bool> hermesGatewayReachable() async {
    try {
      final client = HttpClient();
      final request = await client.getUrl(
        Uri.parse('http://127.0.0.1:8642/health'),
      )..followRedirects = false;
      final response = await request.close().timeout(const Duration(seconds: 3));
      client.close(force: true);
      return response.statusCode == 200;
    } on Exception {
      return false;
    }
  }

  group('Hermes Connection', () {
    test('can connect to local Hermes gateway at :8642', () async {
      final reachable = await hermesGatewayReachable();
      if (!reachable) {
        return;
      }
      final hermesService = HermesStreamingService(
        baseUrl: 'http://127.0.0.1:8642',
        apiKey: apiKey,
      );
      await hermesService.establishConnection();
      expect(hermesService.connection.isActive, isTrue,
          reason: 'Hermes should be reachable at 127.0.0.1:8642');
      hermesService.dispose();
    });

    test('health endpoint returns healthy', () async {
      final reachable = await hermesGatewayReachable();
      if (!reachable) {
        return;
      }
      final hermesService = HermesStreamingService(
        baseUrl: 'http://127.0.0.1:8642',
        apiKey: apiKey,
      );
      await hermesService.establishConnection();
      expect(await hermesService.testConnection(), isTrue);
      hermesService.dispose();
    });
  });

  group('Hermes Streaming', () {
    test('lists hermes-agent from the live gateway', () async {
      final reachable = await hermesGatewayReachable();
      if (!reachable) {
        return;
      }
      expect(apiKey, isNotNull,
          reason: 'API_SERVER_KEY must be in ~/.hermes/.env for live chat');

      final hermesService = HermesStreamingService(
        baseUrl: 'http://127.0.0.1:8642',
        apiKey: apiKey,
      );
      await hermesService.establishConnection();
      final models = await hermesService.getAvailableModels();
      expect(models, contains('hermes-agent'));
      hermesService.dispose();
    });

    test('omits models when the gateway API key is missing', () async {
      final reachable = await hermesGatewayReachable();
      if (!reachable) {
        return;
      }

      final hermesService = HermesStreamingService(
        baseUrl: 'http://127.0.0.1:8642',
      );
      await hermesService.establishConnection();
      // Health is public; /v1/models requires API_SERVER_KEY.
      expect(hermesService.connection.isActive, isTrue);
      final models = await hermesService.getAvailableModels();
      expect(models, isEmpty);
      hermesService.dispose();
    });

    test('streams a MiniMax chat reply through the app runtime client',
        () async {
      final reachable = await hermesGatewayReachable();
      if (!reachable) {
        return;
      }
      expect(apiKey, isNotNull,
          reason: 'API_SERVER_KEY must be in ~/.hermes/.env for live chat');

      final client = HermesRuntimeClient(
        baseUrl: 'http://127.0.0.1:8642',
        apiKey: apiKey,
      );
      await client.connect();
      expect(client.connectionState, RuntimeConnectionState.connected);
      expect(client.capabilityManifest.models, contains('hermes-agent'));

      final reply = await client.sendChatMessage(
        prompt: 'Reply with exactly: MiniMax M3 free on this desktop.',
        model: 'hermes-agent',
      );
      expect(reply, isNotNull);
      expect(reply!.toLowerCase(), contains('minimax'));
      await client.disconnect();
    }, timeout: const Timeout(Duration(seconds: 90)));

    test('yields data chunks then completion from streamChat', () async {
      final reachable = await hermesGatewayReachable();
      if (!reachable) {
        return;
      }
      expect(apiKey, isNotNull);

      final client = HermesRuntimeClient(
        baseUrl: 'http://127.0.0.1:8642',
        apiKey: apiKey,
      );
      await client.connect();

      final chunks = <String>[];
      var sawComplete = false;
      await for (final message in client.streamChat(
        prompt: 'Reply with exactly: STREAM_OK',
        model: 'hermes-agent',
        conversationId: 'live-stream-ok',
      )) {
        expect(message.hasError, isFalse, reason: message.error);
        if (message.isDataChunk) {
          chunks.add(message.chunk);
        }
        if (message.isComplete) {
          sawComplete = true;
        }
      }

      expect(chunks, isNotEmpty);
      expect(sawComplete, isTrue);
      expect(chunks.join().toLowerCase(), contains('stream_ok'));
      await client.disconnect();
    }, timeout: const Timeout(Duration(seconds: 90)));

    test('follow-up chat uses conversation history', () async {
      final reachable = await hermesGatewayReachable();
      if (!reachable) {
        return;
      }
      expect(apiKey, isNotNull);

      final client = HermesRuntimeClient(
        baseUrl: 'http://127.0.0.1:8642',
        apiKey: apiKey,
      );
      await client.connect();

      const codeword = 'BANANA-8642';
      final first = await client.sendChatMessage(
        prompt: 'Remember this codeword: $codeword. Reply with exactly: ACK.',
        model: 'hermes-agent',
      );
      expect(first, isNotNull);

      final second = await client.sendChatMessage(
        prompt: 'What is the codeword I just asked you to remember? Reply with only that codeword.',
        model: 'hermes-agent',
        history: <Map<String, String>>[
          <String, String>{
            'role': 'user',
            'content':
                'Remember this codeword: $codeword. Reply with exactly: ACK.',
          },
          <String, String>{
            'role': 'assistant',
            'content': first!,
          },
        ],
      );
      expect(second, isNotNull);
      expect(second!.toUpperCase(), contains('BANANA-8642'));
      await client.disconnect();
    }, timeout: const Timeout(Duration(seconds: 180)));
  });

  group('HermesProviderAdapter', () {
    test('complete() talks to the live gateway', () async {
      final reachable = await hermesGatewayReachable();
      if (!reachable) {
        return;
      }
      final adapter = HermesProviderAdapter(
        baseUrl: 'http://127.0.0.1:8642',
        apiKey: apiKey,
      );
      final response = await adapter.complete(
        CompletionRequest(
          model: 'hermes-agent',
          messages: <Map<String, dynamic>>[
            <String, dynamic>{
              'role': 'user',
              'content': 'Reply with exactly: adapter-ok.',
            },
          ],
        ),
      );
      expect(response.choices, isNotEmpty);
      expect(response.choices.first.message.content.toLowerCase(),
          contains('adapter-ok'));
      adapter.dispose();
    }, timeout: const Timeout(Duration(seconds: 90)));

    test('streamCompletion() yields OpenAI SSE from MiniMax', () async {
      final reachable = await hermesGatewayReachable();
      if (!reachable) {
        return;
      }
      expect(apiKey, isNotNull);

      final adapter = HermesProviderAdapter(
        baseUrl: 'http://127.0.0.1:8642',
        apiKey: apiKey,
      );
      final events = <String>[];
      await for (final event in adapter.streamCompletion(
        CompletionRequest(
          model: 'hermes-agent',
          messages: <Map<String, dynamic>>[
            <String, dynamic>{
              'role': 'user',
              'content': 'Reply with exactly: SSE_OK',
            },
          ],
          stream: true,
        ),
      )) {
        events.add(event.data);
      }
      expect(events, isNotEmpty);
      expect(events.join().toLowerCase(), contains('sse_ok'));
      adapter.dispose();
    }, timeout: const Timeout(Duration(seconds: 90)));

    test('complete() without API key is rejected', () async {
      final reachable = await hermesGatewayReachable();
      if (!reachable) {
        return;
      }
      final adapter = HermesProviderAdapter(
        baseUrl: 'http://127.0.0.1:8642',
      );
      expect(
        () => adapter.complete(
          CompletionRequest(
            model: 'hermes-agent',
            messages: <Map<String, dynamic>>[
              <String, dynamic>{'role': 'user', 'content': 'hi'},
            ],
          ),
        ),
        throwsA(isA<Exception>()),
      );
      adapter.dispose();
    });
  });
}

String? _discoverHermesApiKey() {
  final home = Platform.environment['HOME'];
  if (home == null || home.isEmpty) {
    return null;
  }
  final envFile = File('$home/.hermes/.env');
  if (!envFile.existsSync()) {
    return null;
  }
  for (final line in envFile.readAsLinesSync()) {
    final trimmed = line.trim();
    if (trimmed.startsWith('API_SERVER_KEY=')) {
      final value = trimmed.substring('API_SERVER_KEY='.length).trim();
      if (value.isNotEmpty) {
        return value;
      }
    }
  }
  return null;
}

class _RealHttpOverrides extends HttpOverrides {}
