import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:pistisai/database/drift_local_brain.dart' as brain;
import 'package:pistisai/services/hermes/hermes_session_key.dart';
import 'package:pistisai/services/hub/hermes_hub_broker.dart';
import 'package:pistisai/services/providers/base_provider.dart' as provider;
import 'package:pistisai/services/rate_limit_manager.dart';
import 'package:pistisai/services/router_server.dart';

void main() {
  setUpAll(() {
    HttpOverrides.global = null;
  });

  group('hub discovery and proxied chat', () {
    HttpServer? hermes;
    RouterServer? hub;
    Uri? hubUri;
    final List<String> hermesRequests = <String>[];

    setUp(() async {
      hermesRequests.clear();
      hermes = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      hermes!.listen((HttpRequest request) async {
        final path = request.uri.path;
        hermesRequests.add('${request.method} $path');
        final body = request.method == 'POST'
            ? await utf8.decoder.bind(request).join()
            : '';
        request.response.headers.contentType = ContentType.json;

        if (request.method == 'POST' && path == '/api/pistisai/messages') {
          request.response.statusCode = HttpStatus.accepted;
          request.response.write(jsonEncode(<String, Object>{
            'echo': jsonDecode(body),
            'session_key': hermesSessionKeyForUiId('pistisai'),
          }));
        } else if (request.method == 'GET' && path.endsWith('/messages')) {
          final key = Uri.decodeComponent(path.split('/')[3]);
          if (key.endsWith(':missing')) {
            request.response.statusCode = HttpStatus.notFound;
            request.response.write(jsonEncode(<String, String>{
              'error': 'not found',
            }));
          } else if (key.endsWith(':conflict')) {
            request.response.statusCode = HttpStatus.conflict;
            request.response.write(jsonEncode(<String, String>{
              'id': 'pistisai',
            }));
          } else {
            request.response.statusCode = HttpStatus.ok;
            request.response.write(jsonEncode(<String, Object>{
              'messages': <Map<String, String>>[
                <String, String>{'role': 'user', 'content': 'hello'},
              ],
            }));
          }
        } else {
          request.response.statusCode = HttpStatus.notFound;
          request.response.write(jsonEncode(<String, String>{
            'error': 'unexpected ${request.method} $path',
          }));
        }
        await request.response.close();
      });

      final port = await _availableLoopbackPort();
      hub = RouterServer(
        port: port,
        rateLimitManager: _TestRateLimitManager(),
        providers: {'zhipu': _EchoProvider()},
        authSecret: 'router-secret',
        hermesHubBroker: HermesHubBroker(
          hermesBaseUrl: 'http://127.0.0.1:${hermes!.port}',
        ),
      );
      await hub!.start();
      hubUri = Uri.parse('http://127.0.0.1:$port');
    });

    tearDown(() async {
      await hub?.stop();
      await hermes?.close(force: true);
      hub = null;
      hermes = null;
    });

    test('discovery advertises the hub and the chat proxy paths', () async {
      final response =
          await http.get(hubUri!.replace(path: '/api/pistisai/hub'));
      expect(response.statusCode, HttpStatus.ok);
      final dynamic body = jsonDecode(response.body);
      expect(body, containsPair('role', 'primary_hub'));
      expect((body as Map)['chat'],
          containsPair('send', '/api/pistisai/messages'));
    });

    test('proxies platform send without inventing a session', () async {
      final denied = await http.post(
        hubUri!.replace(path: '/api/pistisai/messages'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(<String, String>{
          'conversation_id': 'pistisai',
          'text': 'hello',
        }),
      );
      expect(denied.statusCode, HttpStatus.forbidden);
      expect(hermesRequests, isEmpty);

      final response = await http.post(
        hubUri!.replace(path: '/api/pistisai/messages'),
        headers: {
          'Authorization': 'Bearer router-secret',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(<String, String>{
          'conversation_id': 'pistisai',
          'text': 'hello',
        }),
      );

      expect(response.statusCode, HttpStatus.accepted);
      final dynamic forwarded = jsonDecode(response.body);
      expect(forwarded['echo'], containsPair('conversation_id', 'pistisai'));
      expect(forwarded['echo'], containsPair('text', 'hello'));
      expect(hermesRequests, ['POST /api/pistisai/messages']);
      expect(
        hermesRequests.any((entry) => entry.startsWith('POST /api/sessions')),
        isFalse,
      );
    });

    test('proxies the gateway session transcript and keeps 404 and 409',
        () async {
      final sessionKey = hermesSessionKeyForUiId('main-channel');
      expect(sessionKey, 'agent:main:pistisai:dm:pistisai');

      final ok = await http.get(
        hermesSessionMessagesUri(hubUri!.toString(), sessionKey),
        headers: {'Authorization': 'Bearer router-secret'},
      );
      expect(ok.statusCode, HttpStatus.ok);
      final dynamic transcript = jsonDecode(ok.body);
      expect(transcript['messages'], isA<List>());
      expect(hermesRequests.single, isNot(contains('%253A')));
      expect(
        hermesRequests.single.contains('agent:main:pistisai:dm:pistisai') ||
            hermesRequests.single.contains(
              'agent%3Amain%3Apistisai%3Adm%3Apistisai',
            ),
        isTrue,
      );

      final missingKey = hermesSessionKeyForUiId('missing');
      final missing = await http.get(
        hermesSessionMessagesUri(hubUri!.toString(), missingKey),
        headers: {'Authorization': 'Bearer router-secret'},
      );
      expect(missing.statusCode, HttpStatus.notFound);
      expect(missing.body, contains('not found'));
      expect(missing.body, isNot(contains('"messages":[]')));

      final conflictKey = hermesSessionKeyForUiId('conflict');
      final conflict = await http.get(
        hermesSessionMessagesUri(hubUri!.toString(), conflictKey),
        headers: {'Authorization': 'Bearer router-secret'},
      );
      expect(conflict.statusCode, HttpStatus.conflict);
      expect(jsonDecode(conflict.body), containsPair('id', 'pistisai'));
    });
  });
}

Future<int> _availableLoopbackPort() async {
  final socket = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
  final port = socket.port;
  await socket.close();
  return port;
}

class _TestRateLimitManager implements RateLimitManager {
  @override
  brain.LocalBrain get db => throw UnimplementedError();

  @override
  Future<void> endRequest(String modelId) async {}

  @override
  Future<String> getAvailableModel(String requestedModelId) async {
    return requestedModelId;
  }

  @override
  Future<bool> isAvailable(String modelId) async => true;

  @override
  Future<void> startRequest(String modelId) async {}

  @override
  Future<void> syncFromHeader(String modelId, int remaining) async {}

  @override
  Stream<List<brain.ModelCapacityData>> watchCapacities() =>
      const Stream.empty();
}

class _EchoProvider implements provider.LlmProvider {
  @override
  String get baseUrl => 'http://127.0.0.1:0';

  @override
  String get name => 'test-echo';

  @override
  Future<provider.CompletionResponse> complete(
    provider.CompletionRequest request,
  ) async {
    return provider.CompletionResponse(
      id: 'chatcmpl-test',
      object: 'chat.completion',
      created: 0,
      model: request.model,
      choices: [
        provider.Choice(
          index: 0,
          message: provider.Message(role: 'assistant', content: 'hello'),
          finishReason: 'stop',
        ),
      ],
    );
  }

  @override
  Stream<provider.StreamEvent> streamCompletion(
    provider.CompletionRequest request,
  ) {
    return Stream.value(provider.StreamEvent(data: '{"done":true}'));
  }
}
