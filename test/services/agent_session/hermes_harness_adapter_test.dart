import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pistisai/models/conversation.dart';
import 'package:pistisai/services/agent_session/harness_adapter.dart';
import 'package:pistisai/services/agent_session/harness_event.dart';
import 'package:pistisai/services/agent_session/hermes_harness_adapter.dart';
import 'package:pistisai/services/agent_session/runtime_session_map.dart';
import 'package:pistisai/services/hermes/hermes_streaming_service.dart';

/// The Hermes adapter sends turns on an API-server-owned session and reads
/// history through the saved mapping (#1066).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = Conversation.pistisaiChannelId;

  ({MockClient client, List<String> paths}) fakeHermes({
    required List<String> sessions,
    required Map<String, String> transcripts,
    int listStatus = 200,
  }) {
    final paths = <String>[];
    final client = MockClient((request) async {
      paths.add(request.url.path);
      if (request.url.path == '/api/sessions') {
        final rows = [
          for (final id in sessions)
            '{"id":"$id","source":"pistisai","chat":"pistisai",'
                '"last_active":100}',
        ];
        return http.Response('{"data":[${rows.join(',')}]}', listStatus);
      }
      final match = RegExp(r'^/api/sessions/([^/]+)/messages$')
          .firstMatch(request.url.path);
      if (match != null) {
        final body = transcripts[Uri.decodeComponent(match.group(1)!)];
        if (body == null) return http.Response('not found', 404);
        return http.Response(body, 200);
      }
      return http.Response('unexpected', 500);
    });
    return (client: client, paths: paths);
  }

  String transcript(String sessionId) =>
      '{"session_id":"$sessionId","data":['
      '{"id":"u1","role":"user","content":"hi","timestamp":1764000000},'
      '{"id":"a1","role":"assistant","content":"hello","timestamp":1764000005}'
      ']}';

  test('sendTurn creates an API-server session and does not post to the '
      'pistisai platform route', () async {
    final requests = <http.Request>[];
    final client = MockClient((request) async {
      requests.add(request);
      if (request.method == 'POST' && request.url.path == '/api/sessions') {
        return http.Response(
          '{"object":"hermes.session","session":{"id":"api_1"}}',
          201,
        );
      }
      if (request.method == 'POST' &&
          request.url.path == '/api/sessions/api_1/chat') {
        return http.Response(
          '{"message":{"role":"assistant","content":"hello"}}',
          200,
        );
      }
      return http.Response('unexpected', 500);
    });
    final service = HermesStreamingService(client: client);
    final adapter = HermesHarnessAdapter(
      service,
      sessions: await RuntimeSessionMap.load(InMemoryRuntimeSessionMapStore()),
    );
    try {
      expect(adapter.capabilities.streaming, isFalse);
      expect(adapter.capabilities.agentEvents, isFalse);
      expect(adapter.capabilities.proactive, isFalse);
      final events = <HarnessEvent>[];
      final sub = adapter.events(channel).listen(events.add);
      await adapter.sendTurn(channel, 'hi');
      await Future<void>.delayed(Duration.zero);
      await sub.cancel();
      expect(events, hasLength(1));
      expect(events.single, isA<HarnessMessageCompleted>());
      expect(
        (events.single as HarnessMessageCompleted).message.content,
        'hello',
      );
      expect(
        requests.any((request) => request.url.path == '/api/pistisai/messages'),
        isFalse,
      );
      expect(adapter.runtimeSessionFor(channel), 'api_1');
    } finally {
      service.dispose();
    }
  });

  test('resetChannel deletes the owned session and forgets the mapping',
      () async {
    final requests = <http.Request>[];
    final client = MockClient((request) async {
      requests.add(request);
      if (request.method == 'DELETE') return http.Response('', 204);
      return http.Response('unexpected', 500);
    });
    final service = HermesStreamingService(client: client);
    final store = InMemoryRuntimeSessionMapStore();
    await store.save({
      channel: {'hermes': 'api_1'},
    });
    final adapter = HermesHarnessAdapter(
      service,
      sessions: await RuntimeSessionMap.load(store),
    );
    try {
      await adapter.resetChannel(channel);
      expect(adapter.runtimeSessionFor(channel), isNull);
      expect(
        requests.single.method,
        'DELETE',
      );
      expect(requests.single.url.path, '/api/sessions/api_1');
    } finally {
      service.dispose();
    }
  });

  test('fetchHistory reads a saved mapping and does not list sessions',
      () async {
    final hermes = fakeHermes(
      sessions: const [],
      transcripts: {'saved-1': transcript('saved-1')},
    );
    final service = HermesStreamingService(client: hermes.client);
    final store = InMemoryRuntimeSessionMapStore();
    await store.save({
      channel: {'hermes': 'saved-1'},
    });
    final adapter = HermesHarnessAdapter(
      service,
      sessions: await RuntimeSessionMap.load(store),
    );
    try {
      final history = await adapter.fetchHistory(channel);
      expect(history.map((m) => m.id), ['u1', 'a1']);
      expect(hermes.paths, contains('/api/sessions/saved-1/messages'));
      expect(hermes.paths, isNot(contains('/api/sessions')));
    } finally {
      service.dispose();
    }
  });

  test('a saved mapping is handed to the service before the read', () async {
    final hermes = fakeHermes(
      sessions: const [],
      listStatus: 500,
      transcripts: {'saved-1': transcript('saved-1')},
    );
    final service = HermesStreamingService(client: hermes.client);
    final store = InMemoryRuntimeSessionMapStore();
    await store.save({
      channel: {'hermes': 'saved-1'},
    });
    final adapter = HermesHarnessAdapter(
      service,
      sessions: await RuntimeSessionMap.load(store),
    );
    try {
      final history = await adapter.fetchHistory(channel);
      expect(history, hasLength(2));
      expect(hermes.paths, contains('/api/sessions/saved-1/messages'));
    } finally {
      service.dispose();
    }
  });

  test('before a first turn the history is empty and nothing is mapped',
      () async {
    final hermes = fakeHermes(sessions: const [], transcripts: {});
    final service = HermesStreamingService(client: hermes.client);
    final adapter = HermesHarnessAdapter(
      service,
      sessions: await RuntimeSessionMap.load(InMemoryRuntimeSessionMapStore()),
    );
    try {
      expect(await adapter.fetchHistory(channel), isEmpty);
      expect(hermes.paths.where((p) => p.endsWith('/messages')), isEmpty);
      expect(adapter.runtimeSessionFor(channel), isNull);
    } finally {
      service.dispose();
    }
  });

  test('an unreadable mapped transcript is an error, not an empty history',
      () async {
    final client = MockClient((request) async {
      return http.Response('boom', 500);
    });
    final service = HermesStreamingService(client: client);
    final store = InMemoryRuntimeSessionMapStore();
    await store.save({
      channel: {'hermes': 'gen-1'},
    });
    final adapter = HermesHarnessAdapter(
      service,
      sessions: await RuntimeSessionMap.load(store),
    );
    try {
      await expectLater(
        adapter.fetchHistory(channel),
        throwsA(isA<HarnessUnavailableException>()),
      );
    } finally {
      service.dispose();
    }
  });

  test('forgetRuntimeSession clears a saved mapping', () async {
    final service = HermesStreamingService(
      client: fakeHermes(sessions: const [], transcripts: {}).client,
    );
    final store = InMemoryRuntimeSessionMapStore();
    await store.save({
      channel: {'hermes': 'gen-1'},
    });
    final adapter = HermesHarnessAdapter(
      service,
      sessions: await RuntimeSessionMap.load(store),
    );
    try {
      expect(adapter.runtimeSessionFor(channel), 'gen-1');
      await adapter.forgetRuntimeSession(channel);
      expect(adapter.runtimeSessionFor(channel), isNull);
      expect(service.runtimeSessionIdFor(channel), isNull);
    } finally {
      service.dispose();
    }
  });
}
