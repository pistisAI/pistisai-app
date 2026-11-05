import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:pistisai/database/drift_local_brain.dart' as brain;
import 'package:pistisai/services/hermes/hermes_session_key.dart';
import 'package:pistisai/config/app_config.dart';
import 'package:pistisai/services/hub/hermes_hub_broker.dart';
import 'package:pistisai/services/providers/base_provider.dart' as provider;
import 'package:pistisai/services/rate_limit_manager.dart';
import 'package:pistisai/services/router_server.dart';

void main() {
  setUpAll(() {
    HttpOverrides.global = null;
  });

  test('broker uses a custom Hermes base URL and defaults when empty',
      () async {
    final blank = HermesHubBroker(hermesBaseUrl: '  ');
    expect(blank.hermesBaseUrl, AppConfig.defaultHermesUrl);
    blank.close();

    final hermes = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final requests = <String>[];
    hermes.listen((HttpRequest request) async {
      requests.add(request.uri.path);
      request.response.statusCode = HttpStatus.accepted;
      request.response.write('{"ok":true}');
      await request.response.close();
    });
    final custom = HermesHubBroker(
      hermesBaseUrl: 'http://127.0.0.1:${hermes.port}/',
      hermesApiKey: 'custom-key',
    );
    expect(custom.hermesBaseUrl, 'http://127.0.0.1:${hermes.port}');

    final result = await custom.forwardPistisaiMessage(
      body: '{"conversation_id":"pistisai","text":"hi"}',
    );
    expect(result.statusCode, HttpStatus.accepted);
    expect(requests, ['/api/pistisai/messages']);

    custom.close();
    await hermes.close(force: true);
  });

  group('hub discovery and proxied chat', () {
    HttpServer? hermes;
    RouterServer? hub;
    Uri? hubUri;
    final List<String> hermesRequests = <String>[];
    final List<String?> upstreamAuthorization = <String?>[];
    final List<String> upstreamQueries = <String>[];
    var pistisaiTranscriptReads = 0;

    setUp(() async {
      hermesRequests.clear();
      upstreamAuthorization.clear();
      upstreamQueries.clear();
      pistisaiTranscriptReads = 0;
      hermes = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      hermes!.listen((HttpRequest request) async {
        final path = request.uri.path;
        hermesRequests.add('${request.method} $path');
        upstreamAuthorization.add(
          request.headers.value(HttpHeaders.authorizationHeader),
        );
        upstreamQueries.add(request.uri.query);
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
          if (key != 'agent:main:pistisai:dm:pistisai') {
            request.response.statusCode = HttpStatus.ok;
            request.response.write(jsonEncode(<String, String>{
              'error': 'unexpected session $key',
            }));
          } else {
            pistisaiTranscriptReads += 1;
            if (pistisaiTranscriptReads == 2) {
              request.response.statusCode = HttpStatus.notFound;
              request.response.write(jsonEncode(<String, String>{
                'error': 'not found',
              }));
            } else if (pistisaiTranscriptReads == 3) {
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
          hermesApiKey: 'hub-hermes-key',
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
      expect(upstreamAuthorization, ['Bearer hub-hermes-key']);
      expect(
        hermesRequests.any((entry) => entry.startsWith('POST /api/sessions')),
        isFalse,
      );
    });

    test('rejects a foreign conversation id and still forwards pistisai',
        () async {
      final foreign = await http.post(
        hubUri!.replace(path: '/api/pistisai/messages'),
        headers: {
          'Authorization': 'Bearer router-secret',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(<String, String>{
          'conversation_id': 'telegram',
          'text': 'inject',
        }),
      );
      expect(foreign.statusCode, HttpStatus.forbidden);
      expect(hermesRequests, isEmpty);

      final missing = await http.post(
        hubUri!.replace(path: '/api/pistisai/messages'),
        headers: {
          'Authorization': 'Bearer router-secret',
          'Content-Type': 'application/json',
        },
        body: '{"text":"no id"}',
      );
      expect(missing.statusCode, HttpStatus.forbidden);
      expect(hermesRequests, isEmpty);

      final allowed = await http.post(
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
      expect(allowed.statusCode, HttpStatus.accepted);
      final dynamic forwarded = jsonDecode(allowed.body);
      expect(forwarded['echo'], containsPair('conversation_id', 'pistisai'));
      expect(hermesRequests, ['POST /api/pistisai/messages']);
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

      expect(upstreamAuthorization.single, 'Bearer hub-hermes-key');
      expect(upstreamQueries.single, 'order=oldest&limit=500');

      final missing = await http.get(
        hermesSessionMessagesUri(hubUri!.toString(), sessionKey),
        headers: {'Authorization': 'Bearer router-secret'},
      );
      expect(missing.statusCode, HttpStatus.notFound);
      expect(missing.body, contains('not found'));
      expect(missing.body, isNot(contains('"messages":[]')));

      final conflict = await http.get(
        hermesSessionMessagesUri(hubUri!.toString(), sessionKey),
        headers: {'Authorization': 'Bearer router-secret'},
      );
      expect(conflict.statusCode, HttpStatus.conflict);
      expect(jsonDecode(conflict.body), containsPair('id', 'pistisai'));
    });

    test('session proxy rejects other transcripts and caller query overrides',
        () async {
      final unauthenticated = await http.get(
        hermesSessionMessagesUri(
          hubUri!.toString(),
          'agent:main:pistisai:dm:pistisai',
        ),
      );
      expect(unauthenticated.statusCode, HttpStatus.forbidden);
      expect(hermesRequests, isEmpty);

      final foreign = await http.get(
        hermesSessionMessagesUri(
          hubUri!.toString(),
          'agent:main:telegram:dm:ops',
        ),
        headers: {'Authorization': 'Bearer router-secret'},
      );
      expect(foreign.statusCode, HttpStatus.forbidden);
      expect(hermesRequests, isEmpty);

      final widened = hermesSessionMessagesUri(
        hubUri!.toString(),
        'agent:main:pistisai:dm:pistisai',
      ).replace(queryParameters: <String, String>{
        'order': 'newest',
        'limit': '1',
      });
      final kept = await http.get(
        widened,
        headers: {
          'Authorization': 'Bearer router-secret',
        },
      );
      expect(kept.statusCode, HttpStatus.ok);
      expect(upstreamQueries.single, 'order=oldest&limit=500');
      expect(upstreamAuthorization.single, 'Bearer hub-hermes-key');
    });

    test('main-channel is read as the Pistisai DM session key', () async {
      final shell = await http.get(
        hubUri!.replace(path: '/api/sessions/main-channel/messages'),
        headers: {'Authorization': 'Bearer router-secret'},
      );
      expect(shell.statusCode, HttpStatus.ok);
      expect(
        hermesRequests.single.contains('agent:main:pistisai:dm:pistisai') ||
            hermesRequests.single.contains(
              'agent%3Amain%3Apistisai%3Adm%3Apistisai',
            ),
        isTrue,
      );
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
