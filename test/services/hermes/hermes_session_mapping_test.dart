import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pistisai/models/conversation.dart';
import 'package:pistisai/services/hermes/hermes_streaming_service.dart';

/// The Hermes session id is an adapter mapping for the app-owned `pistisai`
/// channel (#1065): resolved once, reused across polls, re-resolved on 404,
/// cleared on demand, and never replaced by the short channel id.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = Conversation.pistisaiChannelId;

  String sessionList(List<String> ids) {
    final rows = [
      for (var i = 0; i < ids.length; i++)
        '{"id":"${ids[i]}","source":"pistisai","chat":"pistisai",'
            '"last_active":${100 + i}}',
    ];
    return '{"data":[${rows.join(',')}]}';
  }

  String transcript(String sessionId, String text) =>
      '{"session_id":"$sessionId","data":[{"id":"$sessionId-1",'
      '"role":"assistant","content":"$text","timestamp":1764000000}]}';

  /// A fake Hermes whose session list and transcripts can change between
  /// calls. Records every request path.
  ({MockClient client, List<String> paths}) fakeHermes({
    required List<String> Function() sessions,
    required Map<String, String> transcripts,
  }) {
    final paths = <String>[];
    final client = MockClient((request) async {
      paths.add(request.url.path);
      if (request.url.path == '/api/sessions') {
        return http.Response(sessionList(sessions()), 200);
      }
      final match = RegExp(r'^/api/sessions/([^/]+)/messages$')
          .firstMatch(request.url.path);
      if (match != null) {
        final id = Uri.decodeComponent(match.group(1)!);
        final body = transcripts[id];
        if (body == null) return http.Response('not found', 404);
        return http.Response(body, 200);
      }
      return http.Response('unexpected', 500);
    });
    return (client: client, paths: paths);
  }

  int resolves(List<String> paths) =>
      paths.where((p) => p == '/api/sessions').length;

  int transcriptReads(List<String> paths) =>
      paths.where((p) => p.endsWith('/messages')).length;

  test('before a first turn no transcript is requested at all', () async {
    final hermes = fakeHermes(sessions: () => const [], transcripts: {});
    final service = HermesStreamingService(client: hermes.client);
    try {
      for (var i = 0; i < 3; i++) {
        expect(await service.fetchSessionMessages(channel), isEmpty);
      }
      expect(transcriptReads(hermes.paths), 0);
      expect(service.runtimeSessionIdFor(channel), isNull);
    } finally {
      service.dispose();
    }
  });

  test('the short channel id is never read as a runtime session', () async {
    // The runtime lists the new session before its transcript exists.
    final hermes = fakeHermes(sessions: () => ['gen-1'], transcripts: {});
    final service = HermesStreamingService(client: hermes.client);
    try {
      expect(await service.fetchSessionMessages(channel), isEmpty);
      expect(
        hermes.paths,
        isNot(contains('/api/sessions/$channel/messages')),
      );
    } finally {
      service.dispose();
    }
  });

  test('the resolved mapping is reused across polls', () async {
    final hermes = fakeHermes(
      sessions: () => ['gen-1'],
      transcripts: {'gen-1': transcript('gen-1', 'hi')},
    );
    final service = HermesStreamingService(client: hermes.client);
    try {
      for (var i = 0; i < 3; i++) {
        final messages = await service.fetchSessionMessages(channel);
        expect(messages!.single.content, 'hi');
      }
      expect(resolves(hermes.paths), 1);
      expect(transcriptReads(hermes.paths), 3);
      expect(service.runtimeSessionIdFor(channel), 'gen-1');
    } finally {
      service.dispose();
    }
  });

  test('a restored mapping is used without resolving again', () async {
    final hermes = fakeHermes(
      sessions: () => ['gen-1'],
      transcripts: {'gen-1': transcript('gen-1', 'saved')},
    );
    final service = HermesStreamingService(client: hermes.client);
    try {
      service.restoreRuntimeSession(channel, 'gen-1');
      final messages = await service.fetchSessionMessages(channel);
      expect(messages!.single.content, 'saved');
      expect(resolves(hermes.paths), 0);
    } finally {
      service.dispose();
    }
  });

  test('a 404 on the mapped session re-resolves it once', () async {
    final hermes = fakeHermes(
      sessions: () => ['gen-2'],
      transcripts: {'gen-2': transcript('gen-2', 'new session')},
    );
    final service = HermesStreamingService(client: hermes.client);
    try {
      service.restoreRuntimeSession(channel, 'gen-old');
      final messages = await service.fetchSessionMessages(channel);
      expect(messages!.single.content, 'new session');
      expect(service.runtimeSessionIdFor(channel), 'gen-2');
      expect(
        hermes.paths,
        isNot(contains('/api/sessions/$channel/messages')),
      );
    } finally {
      service.dispose();
    }
  });

  test('a 404 with nothing to resolve clears the stale mapping', () async {
    final hermes = fakeHermes(sessions: () => const [], transcripts: {});
    final service = HermesStreamingService(client: hermes.client);
    try {
      service.restoreRuntimeSession(channel, 'gen-old');
      expect(await service.fetchSessionMessages(channel), isEmpty);
      expect(service.runtimeSessionIdFor(channel), isNull);
      hermes.paths.clear();
      expect(await service.fetchSessionMessages(channel), isEmpty);
      expect(transcriptReads(hermes.paths), 0);
    } finally {
      service.dispose();
    }
  });

  test('clearing the mapping (local wipe) resolves it again', () async {
    final hermes = fakeHermes(
      sessions: () => ['gen-1'],
      transcripts: {'gen-1': transcript('gen-1', 'hi')},
    );
    final service = HermesStreamingService(client: hermes.client);
    try {
      await service.fetchSessionMessages(channel);
      service.clearRuntimeSession(channel);
      expect(service.runtimeSessionIdFor(channel), isNull);
      await service.fetchSessionMessages(channel);
      expect(resolves(hermes.paths), 2);
    } finally {
      service.dispose();
    }
  });

  test('a stale mapping is checked again after the refresh interval', () async {
    var current = 'gen-1';
    final hermes = fakeHermes(
      sessions: () => [current],
      transcripts: {
        'gen-1': transcript('gen-1', 'old'),
        'gen-2': transcript('gen-2', 'rotated'),
      },
    );
    final service = HermesStreamingService(
      client: hermes.client,
      mappingRefreshInterval: Duration.zero,
    );
    try {
      expect(
          (await service.fetchSessionMessages(channel))!.single.content, 'old');
      current = 'gen-2';
      expect((await service.fetchSessionMessages(channel))!.single.content,
          'rotated');
      expect(service.runtimeSessionIdFor(channel), 'gen-2');
    } finally {
      service.dispose();
    }
  });
}
