import 'dart:convert';
import 'dart:io';

import 'package:pistisai/database/drift_local_brain.dart' as brain;
import 'package:pistisai/services/providers/base_provider.dart' as provider;
import 'package:pistisai/services/rate_limit_manager.dart';
import 'package:pistisai/services/router_server.dart';
import 'package:pistisai/services/voice/cloud_tts_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

void main() {
  setUpAll(() {
    HttpOverrides.global = null;
  });

  group('RouterServer local security defaults', () {
    RouterServer? server;

    tearDown(() async {
      await server?.stop();
      server = null;
    });

    test('can be constructed with default port', () async {
      server = _buildRouter(port: 0);
      expect(server, isNotNull);
    });

    // Tests 1 & 2: re-enabled — auth middleware now implemented (#422).
    test('rejects privileged local requests when no local token is available',
        () async {
      final baseUrl = await _startRouter(serverRef: (value) => server = value);

      final response = await http.post(
        baseUrl.replace(path: '/v1/chat/completions'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'model': 'glm-4-flash',
          'messages': [
            {'role': 'user', 'content': 'hello'},
          ],
        }),
      );

      expect(response.statusCode, HttpStatus.forbidden);
    });

    test('rejects privileged local requests without the configured local token',
        () async {
      final baseUrl = await _startRouter(serverRef: (value) => server = value);

      final response = await http.post(
        baseUrl.replace(path: '/v1/chat/completions'),
        headers: {
          'Authorization': 'Bearer wrong-token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': 'glm-4-flash',
          'messages': [
            {'role': 'user', 'content': 'hello'},
          ],
        }),
      );

      expect(response.statusCode, HttpStatus.unauthorized);
    });

    test('allows privileged local requests with the configured bearer token',
        () async {
      final baseUrl = await _startRouter(serverRef: (value) => server = value);

      final response = await http.post(
        baseUrl.replace(path: '/v1/chat/completions'),
        headers: {
          'Authorization': 'Bearer router-secret',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': 'glm-4-flash',
          'messages': [
            {'role': 'user', 'content': 'hello'},
          ],
        }),
      );

      expect(response.statusCode, HttpStatus.ok);
      expect(jsonDecode(response.body), containsPair('model', 'glm-4-flash'));
    });

    test('keeps health and model listing available locally without a token',
        () async {
      final baseUrl = await _startRouter(serverRef: (value) => server = value);

      final health = await http.get(baseUrl.replace(path: '/health'));
      final models = await http.get(baseUrl.replace(path: '/v1/models'));

      expect(health.statusCode, HttpStatus.ok);
      expect(health.body, 'OK');
      expect(models.statusCode, HttpStatus.ok);
      expect(jsonDecode(models.body), containsPair('object', 'list'));
    });

    group('bind address (#645)', () {
      test('defaults to loopback only', () async {
        final port = await _availableLoopbackPort();
        final server = _buildRouter(port: port);
        addTearDown(server.stop);
        await server.start();
        // Reachable on loopback.
        final ok = await http.get(Uri.parse('http://127.0.0.1:$port/health'));
        expect(ok.statusCode, HttpStatus.ok);
        // The socket is bound to loopback, not all interfaces.
        expect(server.boundAddressForTest, InternetAddress.loopbackIPv4);
      });

      test('binds all interfaces only when remote access is enabled', () async {
        final port = await _availableLoopbackPort();
        final server = RouterServer(
          port: port,
          rateLimitManager: _TestRateLimitManager(),
          providers: {'zhipu': _EchoProvider()},
          authSecret: 'router-secret',
          allowRemoteAccess: true,
        );
        addTearDown(server.stop);
        await server.start();
        expect(server.boundAddressForTest, InternetAddress.anyIPv4);
      });

      test('generates authSecret when remote access is on without one (#804)',
          () async {
        final port = await _availableLoopbackPort();
        final remoteServer = RouterServer(
          port: port,
          rateLimitManager: _TestRateLimitManager(),
          providers: {'zhipu': _EchoProvider()},
          allowRemoteAccess: true,
        );
        addTearDown(remoteServer.stop);
        expect(remoteServer.authSecret, isNotNull);
        expect(remoteServer.authSecret, isNotEmpty);
        await remoteServer.start();
        expect(remoteServer.boundAddressForTest, InternetAddress.anyIPv4);
      });
    });

    group('error responses (#804)', () {
      test('chat completions errors do not echo exception text', () async {
        final baseUrl = await _startRouter(serverRef: (value) => server = value);

        final response = await http.post(
          baseUrl.replace(path: '/v1/chat/completions'),
          headers: {
            'Authorization': 'Bearer router-secret',
            'Content-Type': 'application/json',
          },
          body: '{not-json path=/home/user/secret.gguf',
        );

        expect(response.statusCode, HttpStatus.badRequest);
        expect(response.body, isNot(contains('/home/')));
        expect(response.body, isNot(contains('FormatException')));
        expect(response.body, isNot(contains('not-json')));
      });
    });

    group('accessDecision without a configured secret', () {
      test('lets loopback callers reach private endpoints', () {
        expect(
          RouterServer.accessDecision(
            path: '/api/conscience/thoughts',
            fromLoopback: true,
            authorizationHeader: null,
            authSecret: null,
          ),
          isNull,
        );
      });

      test('rejects other machines on private endpoints', () {
        for (final path in [
          '/v1/chat/completions',
          '/v1/audio/speech',
          '/api/conscience/thoughts',
          '/avatar/traits',
        ]) {
          expect(
            RouterServer.accessDecision(
              path: path,
              fromLoopback: false,
              authorizationHeader: null,
              authSecret: null,
            ),
            HttpStatus.forbidden,
            reason: path,
          );
        }
      });

      test('keeps public discovery paths open to other machines', () {
        for (final path in ['/health', '/v1/models', '/api/pistisai/hub']) {
          expect(
            RouterServer.accessDecision(
              path: path,
              fromLoopback: false,
              authorizationHeader: null,
              authSecret: null,
            ),
            isNull,
            reason: path,
          );
        }
      });
    });

    group('accessDecision with a configured secret', () {
      test('requires the token even from loopback', () {
        expect(
          RouterServer.accessDecision(
            path: '/v1/chat/completions',
            fromLoopback: true,
            authorizationHeader: null,
            authSecret: 'router-secret',
          ),
          HttpStatus.forbidden,
        );
      });

      test('accepts the right token from another machine', () {
        expect(
          RouterServer.accessDecision(
            path: '/v1/chat/completions',
            fromLoopback: false,
            authorizationHeader: 'Bearer router-secret',
            authSecret: 'router-secret',
          ),
          isNull,
        );
      });

      test('rejects a wrong token', () {
        expect(
          RouterServer.accessDecision(
            path: '/v1/chat/completions',
            fromLoopback: false,
            authorizationHeader: 'Bearer nope',
            authSecret: 'router-secret',
          ),
          HttpStatus.unauthorized,
        );
      });
    });

    test('lists only models whose provider is registered', () async {
      final baseUrl = await _startRouter(serverRef: (value) => server = value);

      final response = await http.get(baseUrl.replace(path: '/v1/models'));
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final data = (body['data'] as List<dynamic>).cast<Map<String, dynamic>>();

      expect(data, isNotEmpty);
      expect(data.map((m) => m['owned_by']).toSet(), {'zhipu'});
      expect(data.map((m) => m['id']), contains('glm-4-flash'));
    });

    test('answers a client error for a model of an unregistered provider',
        () async {
      final baseUrl = await _startRouter(serverRef: (value) => server = value);

      for (final model in ['gpt-4-turbo', 'no-such-model']) {
        final response = await http.post(
          baseUrl.replace(path: '/v1/chat/completions'),
          headers: {
            'Authorization': 'Bearer router-secret',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'model': model,
            'messages': [
              {'role': 'user', 'content': 'hello'},
            ],
          }),
        );

        expect(response.statusCode, HttpStatus.notFound, reason: model);
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        final error = body['error'] as Map<String, dynamic>;
        expect(error['code'], 'model_not_found');
      }
    });

    test('advertises an unauthenticated primary hub discovery document',
        () async {
      final baseUrl = await _startRouter(serverRef: (value) => server = value);

      final response =
          await http.get(baseUrl.replace(path: '/api/pistisai/hub'));
      expect(response.statusCode, HttpStatus.ok);
      final dynamic body = jsonDecode(response.body);
      expect(body, containsPair('role', 'primary_hub'));
      expect(body, containsPair('product', 'Pistisai'));
      expect(body, containsPair('hermesPort', 8642));
      expect(body, containsPair('clientsMustUseHub', true));
      expect(body, containsPair('routerPort', baseUrl.port));
    });

    test('refuses cloud LLM completions when consent is not granted', () async {
      final baseUrl = await _startRouter(
        serverRef: (value) => server = value,
        cloudLlmAllowed: () async => false,
      );

      final response = await http.post(
        baseUrl.replace(path: '/v1/chat/completions'),
        headers: {
          'Authorization': 'Bearer router-secret',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': 'glm-4-flash',
          'messages': [
            {'role': 'user', 'content': 'hello'},
          ],
        }),
      );

      expect(response.statusCode, HttpStatus.forbidden);
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final error = body['error'] as Map<String, dynamic>;
      expect(error['code'], 'cloud_llm_consent_required');
    });

    test('refuses Microsoft speech when consent is not granted', () async {
      var edgeTtsInvoked = false;
      final baseUrl = await _startRouter(
        serverRef: (value) => server = value,
        microsoftSpeechAllowed: () async => false,
        ttsService: CloudTtsService(
          isAllowed: () async => true,
          processRunner: (
            executable,
            arguments, {
            Map<String, String>? environment,
            bool runInShell = false,
          }) async {
            edgeTtsInvoked = true;
            return ProcessResult(0, 0, '', '');
          },
        ),
      );

      final response = await http.post(
        baseUrl.replace(path: '/v1/audio/speech'),
        headers: {
          'Authorization': 'Bearer router-secret',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'input': 'hello from the cloud'}),
      );

      expect(response.statusCode, HttpStatus.forbidden);
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final error = body['error'] as Map<String, dynamic>;
      expect(error['code'], 'microsoft_speech_consent_required');
      expect(edgeTtsInvoked, isFalse);
    });
  });
}

RouterServer _buildRouter({
  required int port,
  Future<bool> Function()? cloudLlmAllowed,
  Future<bool> Function()? microsoftSpeechAllowed,
  CloudTtsService? ttsService,
}) {
  return RouterServer(
    port: port,
    rateLimitManager: _TestRateLimitManager(),
    providers: {'zhipu': _EchoProvider()},
    authSecret: 'router-secret',
    // Existing suite exercises registered providers with consent granted.
    cloudLlmAllowed: cloudLlmAllowed ?? () async => true,
    microsoftSpeechAllowed: microsoftSpeechAllowed,
    ttsService: ttsService,
  );
}

Future<Uri> _startRouter({
  required void Function(RouterServer server) serverRef,
  Future<bool> Function()? cloudLlmAllowed,
  Future<bool> Function()? microsoftSpeechAllowed,
  CloudTtsService? ttsService,
}) async {
  final port = await _availableLoopbackPort();
  final server = _buildRouter(
    port: port,
    cloudLlmAllowed: cloudLlmAllowed,
    microsoftSpeechAllowed: microsoftSpeechAllowed,
    ttsService: ttsService,
  );
  serverRef(server);
  await server.start();
  return Uri.parse('http://127.0.0.1:$port');
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
