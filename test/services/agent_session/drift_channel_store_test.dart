import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pistisai/database/drift_local_brain.dart'
    hide Conversation, Message;
import 'package:pistisai/database/local_brain_key_store.dart';
import 'package:pistisai/models/conversation.dart';
import 'package:pistisai/models/message.dart';
import 'package:pistisai/services/agent_session/channel.dart';
import 'package:pistisai/services/agent_session/channel_store.dart';
import 'package:pistisai/services/agent_session/drift_channel_store.dart';
import 'package:pistisai/services/conversation_storage_service.dart';
import 'package:pistisai/services/local_conversation_storage.dart';

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

Conversation sample() {
  return Conversation.mainChannel(agentName: 'Agent').addMessage(
    Message.user(content: 'kept locally', id: 'm1'),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DriftChannelStore', () {
    late LocalBrain db;
    late DriftChannelStore store;

    setUp(() {
      db = LocalBrain.withExecutor(NativeDatabase.memory());
      store = DriftChannelStore(db);
    });

    tearDown(() async {
      await db.close();
    });

    test('round-trips a channel and its messages', () async {
      final conversation = sample().withRuntimeSession('hermes', 'api_1');
      await store.replaceAll([conversation]);

      final loaded = await store.loadAll();
      expect(loaded, hasLength(1));
      expect(loaded.single.channelId, Conversation.pistisaiChannelId);
      expect(loaded.single.channel.kind, ChannelKind.direct);
      expect(loaded.single.messages.single.content, 'kept locally');
      expect(loaded.single.runtimeSessionId('hermes'), 'api_1');
    });

    test('json import flag and hermes import flag survive a rewrite',
        () async {
      await store.replaceAll([sample()]);
      expect(await store.isJsonImported(), isFalse);
      await store.markJsonImported();
      await store.markHermesHistoryImported(Conversation.pistisaiChannelId);

      await store.upsert(sample().addMessage(
            Message.assistant(content: 'reply', model: 'hermes-agent', id: 'a1'),
          ));

      expect(await store.isJsonImported(), isTrue);
      expect(
        await store.isHermesHistoryImported(Conversation.pistisaiChannelId),
        isTrue,
      );
      expect((await store.loadAll()).single.messages, hasLength(2));
    });
  });

  group('JSON import once', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('pistisai-channel-store-');
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    LocalConversationStorage jsonStore() {
      return LocalConversationStorage(
        documentsDirectory: () async => tempDir,
        keyVault: _MemoryVault(),
      );
    }

    test('imports the encrypted file once and then retires it', () async {
      final json = jsonStore();
      await json.saveConversations([sample()]);
      final enc = File('${tempDir.path}/Pistisai/conversations.json.enc');
      expect(await enc.exists(), isTrue);

      final store = InMemoryChannelStore();
      final storage = ConversationStorageService(
        localStorage: json,
        channelStore: store,
      );

      final first = await storage.loadConversations();
      expect(first.single.messages.single.content, 'kept locally');
      expect(await enc.exists(), isFalse);
      expect(
        await File('${enc.path}.retired').exists(),
        isTrue,
      );

      await json.saveConversations([
        sample().addMessage(
          Message.user(content: 'should not be imported again', id: 'm2'),
        ),
      ]);
      // The retired store ignores a file that appears again.
      await File('${tempDir.path}/Pistisai/conversations.json.enc')
          .rename('${tempDir.path}/Pistisai/conversations.json.enc.extra');

      final second = await storage.loadConversations();
      expect(second.single.messages, hasLength(1));
      expect(second.single.messages.single.content, 'kept locally');
    });

    test('a later save does not recreate the encrypted file', () async {
      final json = jsonStore();
      await json.saveConversations([sample()]);
      final store = InMemoryChannelStore();
      final storage = ConversationStorageService(
        localStorage: json,
        channelStore: store,
      );
      await storage.loadConversations();

      final updated = sample().addMessage(
        Message.assistant(content: 'from the database', model: 'hermes-agent'),
      );
      await storage.saveConversations([updated]);

      expect(
        await File('${tempDir.path}/Pistisai/conversations.json.enc').exists(),
        isFalse,
      );
      final loaded = await storage.loadConversations();
      expect(loaded.single.messages.last.content, 'from the database');
    });
  });
}
