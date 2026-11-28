import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pistisai/models/conversation.dart';
import 'package:pistisai/services/agent_session/harness_adapter.dart';
import 'package:pistisai/services/agent_session/harness_event.dart';
import 'package:pistisai/services/agent_session/hermes_harness_adapter.dart';
import 'package:pistisai/services/agent_session/runtime_session_map.dart';
import 'package:pistisai/services/hermes/hermes_streaming_service.dart';
import 'package:pistisai/services/streaming_chat_service.dart';

/// The Hermes adapter delegates to HermesStreamingService and reports only
/// what the polling transport does (#1066).
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

  test('reports honest capabilities and stays out of the send path', () async {
    final service = HermesStreamingService(
      client: fakeHermes(sessions: const [], transcripts: {}).client,
    );
    final adapter = HermesHarnessAdapter(
      service,
      sessions: await RuntimeSessionMap.load(InMemoryRuntimeSessionMapStore()),
    );
    try {
      expect(adapter, isA<HarnessAdapter>());
      expect(adapter.harnessId, 'hermes');
      expect(adapter.capabilities, const HarnessCapabilities());
      expect(adapter.capabilities.streaming, isFalse);
      expect(adapter.capabilities.agentEvents, isFalse);
      expect(adapter.capabilities.proactive, isFalse);
      expect(() => adapter.sendTurn(channel, 'hi'), throwsUnsupportedError);
      expect(() => adapter.resetChannel(channel), throwsUnsupportedError);
      expect(await adapter.events(channel).isEmpty, isTrue);
    } finally {
      service.dispose();
    }
  });

  test('fetchHistory delegates and records the resolved session', () async {
    final hermes = fakeHermes(
      sessions: ['gen-1'],
      transcripts: {'gen-1': transcript('gen-1')},
    );
    final service = HermesStreamingService(client: hermes.client);
    final store = InMemoryRuntimeSessionMapStore();
    final adapter = HermesHarnessAdapter(
      service,
      sessions: await RuntimeSessionMap.load(store),
    );
    try {
      final history = await adapter.fetchHistory(channel);

      expect(history.map((m) => m.id), ['u1', 'a1']);
      expect(history.map((m) => m.role),
          [HarnessRole.user, HarnessRole.assistant]);
      expect(hermes.paths, contains('/api/sessions/gen-1/messages'));
      expect(adapter.runtimeSessionFor(channel), 'gen-1');
      expect(service.runtimeSessionIdFor(channel), 'gen-1');
      expect((await store.load())[channel], {'hermes': 'gen-1'});

      final since = DateTime.fromMillisecondsSinceEpoch(1764000002 * 1000);
      final later = await adapter.fetchHistory(channel, since: since);
      expect(later.map((m) => m.id), ['a1']);

      // The rows convert back to the messages the chat merged before.
      final message = messageFromHarness(history.last, adapter.harnessId);
      expect(message.model, 'hermes-agent');
      expect(message.content, 'hello');
      expect(message.timestamp.isUtc, isFalse);
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

  test('an unreadable transcript is an error, not an empty history',
      () async {
    final client = MockClient((request) async {
      if (request.url.path == '/api/sessions') {
        return http.Response(
          '{"data":[{"id":"gen-1","source":"pistisai","chat":"pistisai",'
          '"last_active":1}]}',
          200,
        );
      }
      return http.Response('boom', 500);
    });
    final service = HermesStreamingService(client: client);
    final adapter = HermesHarnessAdapter(
      service,
      sessions: await RuntimeSessionMap.load(InMemoryRuntimeSessionMapStore()),
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

  test('forgetRuntimeSession clears the map and the service', () async {
    final hermes = fakeHermes(
      sessions: ['gen-1'],
      transcripts: {'gen-1': transcript('gen-1')},
    );
    final service = HermesStreamingService(client: hermes.client);
    final adapter = HermesHarnessAdapter(
      service,
      sessions: await RuntimeSessionMap.load(InMemoryRuntimeSessionMapStore()),
    );
    try {
      await adapter.fetchHistory(channel);
      await adapter.forgetRuntimeSession(channel);
      expect(adapter.runtimeSessionFor(channel), isNull);
      expect(service.runtimeSessionIdFor(channel), isNull);
    } finally {
      service.dispose();
    }
  });
}
