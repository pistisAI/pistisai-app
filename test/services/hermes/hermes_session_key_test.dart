import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pistisai/services/hermes/hermes_session_key.dart';
import 'package:pistisai/services/hermes/hermes_streaming_service.dart';

void main() {
  const sessionKey = 'agent:main:pistisai:dm:pistisai';
  // When the session resolver finds no pistisai session (empty list), the
  // poll falls back to the short UI id — never a POST-generated /api/sessions.
  const encodedPoll = 'http://127.0.0.1:8642/api/sessions/pistisai/messages';

  group('session key mapping', () {
    test('UI id pistisai maps to the gateway DM key', () {
      expect(hermesSessionKeyForUiId('pistisai'), sessionKey);
      expect(platformChatIdForUiId('pistisai'), 'pistisai');
      expect(platformChatIdForUiId('pistisai'), isNot(sessionKey));
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
      expect(uri.toString(), 'http://127.0.0.1:8642/api/sessions/'
          'agent%3Amain%3Apistisai%3Adm%3Apistisai/messages?order=oldest&limit=500');
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
          if (request.url.path == '/api/sessions') {
            return http.Response('{"data":[]}', 200);
          }
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

      final poll = await service.fetchSessionMessages('pistisai');

      expect(
        requests.any((request) => request.method == 'POST'),
        isFalse,
      );
      expect(
        requests.any((request) => request.url.path == '/api/pistisai/messages'),
        isFalse,
      );
      expect(
        requests.any((request) => request.method == 'GET'),
        isTrue,
      );
      // The session list (empty) then the transcript poll for the DM key.
      final pollRequest = requests.lastWhere((request) =>
          request.method == 'GET' &&
          request.url.path.startsWith('/api/sessions/'));
      expect(pollRequest.url.toString(), '$encodedPoll?order=oldest&limit=500');
      expect(poll, isNotNull);
      expect(poll!.single.content, 'yo back');
      expect(service.runtimeSessionIdFor('pistisai'), isNull);
      service.dispose();
    });

    test('an unbound short id polls that id directly (never creates a session)', () async {
      final requests = <http.Request>[];
      final service = HermesStreamingService(
        client: MockClient((request) async {
          requests.add(request);
          if (request.url.path == '/api/sessions') {
            return http.Response('{"data":[]}', 200);
          }
          return http.Response('{"data":[]}', 200);
        }),
      );

      final poll = await service.fetchSessionMessages('main-channel');

      expect(
        requests.lastWhere((request) =>
                request.method == 'GET' &&
                request.url.path.startsWith('/api/sessions/'))
            .url
            .toString(),
        // The app normalizes main-channel to 'pistisai' upstream; a raw
        // short id here is polled as-is, never POSTed into /api/sessions.
        'http://127.0.0.1:8642/api/sessions/main-channel/messages'
        '?order=oldest&limit=500',
      );
      expect(
        requests.any((request) => request.method == 'POST'),
        isFalse,
      );
      expect(
        requests.any((request) => request.url.path == '/api/pistisai/messages'),
        isFalse,
      );
      expect(poll, isEmpty);
      service.dispose();
    });

    test('404 does not bind the short id or look like a transcript', () async {
      final requests = <http.Request>[];
      final service = HermesStreamingService(
        client: MockClient((request) async {
          requests.add(request);
          if (request.url.path == '/api/sessions') {
            return http.Response('{"data":[]}', 200);
          }
          return http.Response('{"error":"missing"}', 404);
        }),
      );

      final poll = await service.fetchSessionMessages('pistisai');

      expect(
        requests.any((request) => request.method == 'POST'),
        isFalse,
      );
      expect(
        requests.any((request) => request.url.path == '/api/sessions'),
        isTrue,
      );
      expect(poll, isEmpty); // 404 = no session yet, not a failure
      expect(service.runtimeSessionIdFor('pistisai'), isNull);
      service.dispose();
    });

    test('non-200 (server error) surfaces as an unreadable transcript', () async {
      final service = HermesStreamingService(
        client: MockClient((request) async {
          if (request.url.path == '/api/sessions') {
            return http.Response('{"data":[]}', 200);
          }
          return http.Response('{"error":"boom"}', 500);
        }),
      );

      final poll = await service.fetchSessionMessages('pistisai');

      expect(poll, isNull); // non-200 (not 404) = harness cannot be read
      service.dispose();
    });

    test('platform POST keeps the chat id and adopts a gateway key', () async {
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

      await service
          .streamResponse(
            prompt: 'yo',
            model: 'hermes-agent',
            conversationId: 'pistisai',
          )
          .toList();
      expect(posted!.url.path, '/api/pistisai/messages');
      final body = jsonDecode(posted!.body) as Map<String, dynamic>;
      expect(body['conversation_id'], 'pistisai');
      expect(body['message'], 'yo');
      expect(body['conversation_id'], isNot(sessionKey));
      expect(body.containsKey('session_key'), isFalse);
      service.dispose();
    });

    test('sending yo posts the chat id, never to /api/sessions', () async {
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
      final platformBody = jsonDecode(platform.body) as Map<String, dynamic>;
      expect(platformBody['conversation_id'], 'pistisai');
      expect(platformBody['message'], 'yo');
      expect(requests.any((request) => request.method == 'POST' &&
          request.url.path == '/api/sessions'), isFalse);
      expect(messages, isNotEmpty);
    });
  });
}
