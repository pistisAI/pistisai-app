import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pistisai/services/hermes/hermes_session_key.dart';
import 'package:pistisai/services/hermes/hermes_streaming_service.dart';

void main() {
  const sessionKey = 'agent:main:pistisai:dm:pistisai';
  const encodedPoll =
      'http://127.0.0.1:8642/api/sessions/agent%3Amain%3Apistisai%3Adm%3Apistisai/messages?order=oldest&limit=500';

  group('session key mapping', () {
    test('UI id pistisai maps to the gateway DM key', () {
      expect(hermesSessionKeyForUiId('pistisai'), sessionKey);
      expect(platformChatIdForUiId('pistisai'), 'pistisai');
      expect(platformChatIdForUiId('pistisai'), isNot(sessionKey));
    });

    test('hub proxy allowlist is only the shared Pistisai DM', () {
      expect(hubAllowlistedSessionKey(sessionKey), sessionKey);
      expect(hubAllowlistedSessionKey('pistisai'), sessionKey);
      expect(hubAllowlistedSessionKey('main-channel'), sessionKey);
      expect(hubAllowlistedSessionKey('pistisai-chat'), sessionKey);
      expect(
        hubAllowlistedSessionKey('agent:main:telegram:dm:ops'),
        isNull,
      );
      expect(
        hubAllowlistedSessionKey('agent:main:pistisai:dm:alice'),
        isNull,
      );
    });

    test('local main-channel shell uses the same pistisai DM', () {
      expect(hermesSessionKeyForUiId('main-channel'), sessionKey);
      expect(platformChatIdForUiId('main-channel'), 'pistisai');
      expect(hermesSessionKeyForUiId('pistisai-chat'), sessionKey);
    });

    test('other chat ids stay in the pistisai DM key', () {
      expect(hermesSessionKeyForUiId('alice'), 'agent:main:pistisai:dm:alice');
      expect(platformChatIdForUiId('alice'), 'alice');
    });

    test('a gateway key is not wrapped again', () {
      expect(hermesSessionKeyForUiId(sessionKey), sessionKey);
      expect(platformChatIdForUiId(sessionKey), 'pistisai');
    });

    test('poll URL encodes the session key', () {
      final uri = hermesSessionMessagesUri('http://127.0.0.1:8642', sessionKey);
      expect(uri.toString(), encodedPoll);
      expect(uri.path, isNot(contains('/pistisai/messages')));
    });
  });

  group('failed sync is not an empty success', () {
    test('404 and 409 back off and do not apply a transcript', () {
      for (final status in <int>[404, 409]) {
        final plan = SharedChannelSyncPlan.fromPoll(
          healthy: false,
          consecutiveFailures: 1,
        );
        expect(plan.applyTranscript, isFalse, reason: 'status $status');
        expect(plan.error, sharedChannelSyncError);
        expect(plan.retryAfter, const Duration(seconds: 2));
      }
    });

    test('backoff grows and then caps', () {
      expect(sharedChannelFailureBackoff(1), const Duration(seconds: 2));
      expect(sharedChannelFailureBackoff(2), const Duration(seconds: 4));
      expect(sharedChannelFailureBackoff(3), const Duration(seconds: 8));
      expect(sharedChannelFailureBackoff(5), const Duration(seconds: 32));
      expect(sharedChannelFailureBackoff(9), const Duration(seconds: 32));
    });

    test('a healthy empty 200 can apply; a failed read cannot', () {
      final healthy = SharedChannelSyncPlan.fromPoll(
        healthy: true,
        consecutiveFailures: 4,
      );
      expect(healthy.applyTranscript, isTrue);
      expect(healthy.error, isNull);

      final failed = SharedChannelSyncPlan.fromPoll(
        healthy: false,
        consecutiveFailures: 3,
      );
      expect(failed.applyTranscript, isFalse);
      expect(failed.retryAfter, const Duration(seconds: 8));
    });

    test('the gate does not poll again during backoff', () {
      var now = DateTime.utc(2026, 11, 5);
      final gate = SharedChannelSyncGate(clock: () => now);

      expect(gate.shouldPoll, isTrue);
      gate.record(healthy: false, retryAfter: const Duration(seconds: 2));
      expect(gate.shouldPoll, isFalse);
      expect(gate.failures, 1);

      now = now.add(const Duration(milliseconds: 750));
      expect(gate.shouldPoll, isFalse);

      now = now.add(const Duration(seconds: 2));
      expect(gate.shouldPoll, isTrue);

      gate.record(healthy: true, retryAfter: Duration.zero);
      expect(gate.failures, 0);
      expect(gate.shouldPoll, isTrue);
    });

    test('409 body with the short id is not adopted', () {
      expect(
        adoptGatewaySessionKey(
          statusCode: 409,
          body: <String, Object>{'id': 'pistisai'},
        ),
        isNull,
      );
      expect(
        adoptGatewaySessionKey(
          statusCode: 200,
          body: <String, Object>{'session_id': 'pistisai'},
        ),
        isNull,
      );
      expect(
        adoptGatewaySessionKey(
          statusCode: 202,
          body: <String, Object>{'session_key': sessionKey},
        ),
        sessionKey,
      );
    });
  });

  group('HermesStreamingService transcript poll', () {
    test('polls the encoded gateway key and does not POST a session', () async {
      final requests = <http.Request>[];
      final service = HermesStreamingService(
        client: MockClient((request) async {
          requests.add(request);
          return http.Response(
            jsonEncode(<String, Object>{
              'object': 'list',
              'data': <Object>[
                <String, Object>{
                  'id': 'reply',
                  'role': 'assistant',
                  'content': 'yo back',
                  'timestamp': 20,
                },
              ],
            }),
            200,
          );
        }),
      );

      final poll = await service.pollSharedTranscript('pistisai');

      expect(requests, hasLength(1));
      expect(requests.single.method, 'GET');
      expect(requests.single.url.toString(), encodedPoll);
      expect(poll.isHealthy, isTrue);
      expect(poll.boundShortId, isFalse);
      expect(poll.sessionKey, sessionKey);
      expect(poll.messages, isNotNull);
      expect(poll.messages!.single.content, 'yo back');
      expect(service.boundGatewaySessionKey, isNull);
      service.dispose();
    });

    test('main-channel polls the pistisai DM key', () async {
      final requests = <http.Request>[];
      final service = HermesStreamingService(
        client: MockClient((request) async {
          requests.add(request);
          return http.Response('{"data":[]}', 200);
        }),
      );

      final poll = await service.pollSharedTranscript('main-channel');

      expect(requests.single.url.toString(), encodedPoll);
      expect(poll.isHealthy, isTrue);
      expect(poll.messages, isEmpty);
      service.dispose();
    });

    test(
      '404 does not bind the short id or look like an empty transcript',
      () async {
        final requests = <http.Request>[];
        final service = HermesStreamingService(
          client: MockClient((request) async {
            requests.add(request);
            return http.Response('{"error":"missing"}', 404);
          }),
        );

        final poll = await service.pollSharedTranscript('pistisai');
        final fetched = await service.fetchSessionMessages('pistisai');

        expect(requests, hasLength(2));
        expect(requests.every((request) => request.method == 'GET'), isTrue);
        expect(
          requests.every((request) => request.url.toString() == encodedPoll),
          isTrue,
        );
        expect(poll.isHealthy, isFalse);
        expect(poll.statusCode, 404);
        expect(poll.messages, isNull);
        expect(poll.boundShortId, isFalse);
        expect(poll.sessionKey, isNot('pistisai'));
        expect(fetched, isNull);
        expect(service.boundGatewaySessionKey, isNull);
        service.dispose();
      },
    );

    test('409 does not lock the short id as the runtime session', () async {
      final requests = <http.Request>[];
      final service = HermesStreamingService(
        client: MockClient((request) async {
          requests.add(request);
          if (request.method == 'POST') {
            return http.Response(
              jsonEncode(<String, Object>{'id': 'pistisai'}),
              409,
            );
          }
          return http.Response(
            jsonEncode(<String, Object>{'id': 'pistisai'}),
            409,
          );
        }),
      );

      final delivery = await service.postPistisaiMessage(
        text: 'yo',
        conversationId: 'pistisai',
      );
      final poll = await service.pollSharedTranscript('pistisai');

      expect(delivery.conversationId, 'pistisai');
      expect(delivery.sessionKey, sessionKey);
      expect(delivery.adoptedSessionKey, isNull);
      expect(delivery.boundShortId, isFalse);
      expect(delivery.conversationId, isNot(delivery.sessionKey));
      expect(service.boundGatewaySessionKey, isNull);
      expect(poll.sessionKey, sessionKey);
      expect(poll.isHealthy, isFalse);
      expect(poll.messages, isNull);
      expect(
        requests.where((request) => request.method == 'POST'),
        hasLength(1),
      );
      expect(
        requests.where((request) => request.method == 'POST').single.url.path,
        '/api/pistisai/messages',
      );
      expect(
        requests.any((request) => request.url.path == '/api/sessions'),
        isFalse,
      );
      service.dispose();
    });

    test(
      'platform POST keeps the chat id and can adopt a gateway key',
      () async {
        http.Request? posted;
        final service = HermesStreamingService(
          client: MockClient((request) async {
            if (request.method == 'POST') {
              posted = request;
              return http.Response(
                jsonEncode(<String, Object>{'session_key': sessionKey}),
                202,
              );
            }
            return http.Response('{"data":[]}', 200);
          }),
        );

        final delivery = await service.postPistisaiMessage(
          text: 'yo',
          conversationId: 'main-channel',
        );
        final poll = await service.pollSharedTranscript('pistisai');

        expect(posted, isNotNull);
        expect(posted!.url.path, '/api/pistisai/messages');
        final body = jsonDecode(posted!.body) as Map<String, dynamic>;
        expect(body['conversation_id'], 'pistisai');
        expect(body['text'], 'yo');
        expect(body['conversation_id'], isNot(sessionKey));
        expect(body.containsKey('session_key'), isFalse);
        expect(delivery.adoptedSessionKey, sessionKey);
        expect(service.boundGatewaySessionKey, sessionKey);
        expect(poll.pollUri.toString(), encodedPoll);
        service.dispose();
      },
    );

    test(
      'sending yo posts the chat id and runs against the session key',
      () async {
        final requests = <http.Request>[];
        final service = HermesStreamingService(
          client: MockClient((request) async {
            requests.add(request);
            if (request.url.path == '/health') {
              return http.Response('{"status":"ok"}', 200);
            }
            if (request.url.path == '/v1/models') {
              return http.Response('{"data":[]}', 200);
            }
            if (request.url.path == '/api/pistisai/messages') {
              return http.Response(
                jsonEncode(<String, Object>{'session_key': sessionKey}),
                202,
              );
            }
            return http.Response('{"error":"run failed"}', 500);
          }),
        );

        final messages = await service
            .streamResponse(
              prompt: 'yo',
              model: 'hermes-agent',
              conversationId: 'pistisai',
            )
            .toList();

        final platform = requests.singleWhere(
          (request) => request.url.path == '/api/pistisai/messages',
        );
        final run = requests.singleWhere(
          (request) => request.url.path == '/v1/runs',
        );
        final platformBody = jsonDecode(platform.body) as Map<String, dynamic>;
        final runBody = jsonDecode(run.body) as Map<String, dynamic>;

        expect(platformBody['conversation_id'], 'pistisai');
        expect(platformBody['text'], 'yo');
        expect(runBody['session_id'], sessionKey);
        expect(run.headers['x-hermes-session-key'], sessionKey);
        expect(run.headers['x-hermes-session-id'], sessionKey);
        expect(
          requests.any((request) => request.url.path == '/api/sessions'),
          isFalse,
        );
        expect(service.boundGatewaySessionKey, sessionKey);
        expect(messages, isNotEmpty);
        expect(messages.last.hasError, isTrue);
        service.dispose();
      },
    );
  });
}
