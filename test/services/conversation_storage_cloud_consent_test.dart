import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pistisai/database/local_brain_key_store.dart';
import 'package:pistisai/models/conversation.dart';
import 'package:pistisai/models/message.dart';
import 'package:pistisai/services/conversation_storage_service.dart';
import 'package:pistisai/services/local_conversation_storage.dart';

import '../helpers/mock_services.dart';

class _MemoryVault implements LocalBrainKeyVault {
  final Map<String, String> store = {};

  @override
  Future<String?> read(String key) async => store[key];

  @override
  Future<void> write(String key, String value) async {
    store[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    store.remove(key);
  }
}

/// Records every request instead of sending it.
class _RecordingAdapter implements HttpClientAdapter {
  final List<RequestOptions> sent = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    sent.add(options);
    return ResponseBody.fromString(
      jsonEncode({'conversations': <Object>[]}),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

/// Chat history leaves the device only when the user is signed in AND has
/// turned cloud services on (issue #1010, AGENTS.md "Nothing leaves the
/// device without consent").
void main() {
  late Directory tempDir;
  late _RecordingAdapter adapter;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('pistisai-chat-consent-');
    adapter = _RecordingAdapter();
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  ConversationStorageService storage({
    Future<bool> Function()? cloudAllowed,
    bool signedIn = true,
  }) {
    final dio = Dio(BaseOptions(baseUrl: 'https://api.example.com'))
      ..httpClientAdapter = adapter;
    return ConversationStorageService(
      authService: createMockAuthService(authenticated: signedIn),
      cloudAllowed: cloudAllowed,
      dio: dio,
      localStorage: LocalConversationStorage(
        documentsDirectory: () async => tempDir,
        keyVault: _MemoryVault(),
      ),
    );
  }

  Conversation chat() => Conversation.mainChannel(model: 'hermes-agent')
      .addMessage(Message.user(content: 'private message text'));

  Future<void> exerciseEveryApiPath(ConversationStorageService s) async {
    final c = chat();
    await s.saveConversations([c]);
    await s.saveConversation(c);
    await s.loadConversationWithMessages(c.id);
    await s.deleteConversation(c.id);
    await s.clearAllConversations();
    // Local store is now empty, so this would fall back to the API.
    await s.loadConversations();
  }

  for (final entry in <String, Future<bool> Function()?>{
    'cloud services off': () async => false,
    'no consent check wired': null,
    'consent check fails': () async => throw StateError('prefs'),
  }.entries) {
    test('signed in, ${entry.key}: no request to /api/conversations', () async {
      await exerciseEveryApiPath(storage(cloudAllowed: entry.value));
      expect(adapter.sent, isEmpty);
    });
  }

  test('signed in, cloud services off: history is still saved locally',
      () async {
    final s = storage(cloudAllowed: () async => false);
    await s.saveConversations([chat()]);
    final loaded = await s.loadConversations();
    expect(loaded, hasLength(1));
    expect(loaded.single.messages.single.content, 'private message text');
    expect(adapter.sent, isEmpty);
  });

  test('signed in, cloud services on: the conversation is uploaded', () async {
    final s = storage(cloudAllowed: () async => true);
    final c = chat();
    await s.saveConversations([c]);

    expect(adapter.sent, hasLength(1));
    final put = adapter.sent.single;
    expect(put.method, 'PUT');
    expect(put.path, '/api/conversations/${c.id}');
  });

  test('signed out, cloud services on: nothing is sent', () async {
    await exerciseEveryApiPath(
        storage(cloudAllowed: () async => true, signedIn: false));
    expect(adapter.sent, isEmpty);
  });

  test('the switch is read at each call', () async {
    var on = true;
    var reads = 0;
    final s = storage(cloudAllowed: () async {
      reads++;
      return on;
    });

    await s.saveConversation(chat());
    expect(adapter.sent, hasLength(1));

    on = false;
    await s.saveConversation(chat());
    await s.saveConversations([chat()]);
    expect(adapter.sent, hasLength(1));
    expect(reads, greaterThanOrEqualTo(3));
  });
}
