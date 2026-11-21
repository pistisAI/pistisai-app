import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pistisai/database/local_brain_key_store.dart';
import 'package:pistisai/models/conversation.dart';
import 'package:pistisai/models/message.dart';
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

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('pistisai-chat-');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('pistisai channel survives a new storage instance via secure vault',
      () async {
    Future<Directory> docs() async => tempDir;
    final vault = _MemoryVault();

    final first = LocalConversationStorage(
      documentsDirectory: docs,
      keyVault: vault,
    );
    final original = Conversation.mainChannel(model: 'hermes-agent').addMessage(
      Message.user(content: 'Who are you? One sentence.'),
    );
    await first.saveConversations([original]);

    final second = LocalConversationStorage(
      documentsDirectory: docs,
      keyVault: vault,
    );
    final loaded = await second.loadConversations();

    expect(loaded, hasLength(1));
    expect(loaded.first.id, Conversation.pistisaiChannelId);
    expect(loaded.first.messages, hasLength(1));
    expect(loaded.first.messages.first.content, contains('Who are you?'));
    expect(
      vault.store.containsKey('local_conversation_encryption_key'),
      isTrue,
    );
    final keyFile = File('${tempDir.path}/Pistisai/.conversation_key');
    expect(keyFile.existsSync(), isFalse,
        reason: 'AES key must not be written as a plaintext file');
  });

  test(
      'migrates legacy plaintext .conversation_key into the vault and deletes it',
      () async {
    Future<Directory> docs() async => tempDir;
    final vault = _MemoryVault();
    final pistisaiDir = Directory('${tempDir.path}/Pistisai')..createSync();
    final legacyKey = File('${pistisaiDir.path}/.conversation_key');
    final keyB64 = base64Encode(List<int>.filled(32, 0));
    legacyKey.writeAsStringSync(keyB64);

    final seed = LocalConversationStorage(
      documentsDirectory: docs,
      keyVault: vault,
    );
    // Force key resolution (and migration) by saving.
    await seed.saveConversations([
      Conversation.mainChannel(model: 'hermes-agent').addMessage(
        Message.user(content: 'after-key-migration'),
      ),
    ]);

    expect(vault.store['local_conversation_encryption_key'], keyB64);
    expect(legacyKey.existsSync(), isFalse);
  });

  test('migrates encrypted history from the interim chat/ directory', () async {
    Future<Directory> docs() async => tempDir;
    final vault = _MemoryVault();

    final interim = Directory('${tempDir.path}/chat')..createSync();
    final first = LocalConversationStorage(
      documentsDirectory: () async => interim.parent,
      keyVault: vault,
    );

    // Seed the interim path by writing through a storage that uses chat/
    // via the legacy probe: write files directly after a normal save to Pistisai,
    // then move them into chat/ and delete Pistisai to simulate the old layout.
    final seed = LocalConversationStorage(
      documentsDirectory: docs,
      keyVault: vault,
    );
    await seed.saveConversations([
      Conversation.mainChannel(model: 'hermes-agent').addMessage(
        Message.user(content: 'migrated-from-chat-dir'),
      ),
    ]);
    final pistisaiDir = Directory('${tempDir.path}/Pistisai');
    File('${pistisaiDir.path}/conversations.json.enc')
        .copySync('${interim.path}/conversations.json.enc');
    pistisaiDir.deleteSync(recursive: true);

    final loaded = await first.loadConversations();
    expect(loaded, hasLength(1));
    expect(loaded.first.messages.first.content, 'migrated-from-chat-dir');
    expect(
      File('${tempDir.path}/Pistisai/conversations.json.enc').existsSync(),
      isTrue,
    );
  });

  test('clearAll deletes legacy copies so reload cannot restore history',
      () async {
    Future<Directory> docs() async => tempDir;
    final vault = _MemoryVault();

    final storage = LocalConversationStorage(
      documentsDirectory: docs,
      keyVault: vault,
    );
    await storage.saveConversations([
      Conversation.mainChannel(model: 'hermes-agent').addMessage(
        Message.user(content: 'should-not-survive-wipe'),
      ),
    ]);

    // Simulate an install that still has the interim chat/ copy left behind
    // after migration (encrypted source is never deleted by migration).
    final interim = Directory('${tempDir.path}/chat')..createSync();
    final pistisaiDir = Directory('${tempDir.path}/Pistisai');
    File('${pistisaiDir.path}/conversations.json.enc')
        .copySync('${interim.path}/conversations.json.enc');

    await storage.clearAll();

    final afterWipe = LocalConversationStorage(
      documentsDirectory: docs,
      keyVault: vault,
    );
    final loaded = await afterWipe.loadConversations();
    expect(loaded, isEmpty,
        reason: 'legacy chat/ copy must not restore wiped history');
    expect(
      File('${tempDir.path}/Pistisai/conversations.json.enc').existsSync(),
      isFalse,
    );
    expect(
      File('${tempDir.path}/chat/conversations.json.enc').existsSync(),
      isFalse,
    );
  });

  test('Conversation.mainChannel always uses the stable pistisai session id',
      () {
    expect(Conversation.mainChannel().id, Conversation.pistisaiChannelId);
    expect(
      Conversation.mainChannel(model: 'hermes-agent').id,
      Conversation.pistisaiChannelId,
    );
    expect(Conversation.pistisaiChannelId, 'pistisai');
  });

  test('Conversation.mainChannel titles the thread with the setup agent', () {
    expect(Conversation.mainChannel().title, 'Agent');
    expect(
      Conversation.mainChannel(agentName: 'Hermes MiniMax').title,
      'Hermes MiniMax',
    );
    expect(Conversation.mainChannel(agentName: '  ').title, 'Agent');
  });

  group('history is never overwritten when the key is lost (#894)', () {
    Future<Directory> docs() async => tempDir;
    File encFile() => File('${tempDir.path}/Pistisai/conversations.json.enc');
    List<File> setAside() => Directory('${tempDir.path}/Pistisai')
        .listSync()
        .whereType<File>()
        .where((f) => f.path.contains('.unreadable-'))
        .toList();

    Future<String> saveOne(_MemoryVault vault, String text) async {
      final storage =
          LocalConversationStorage(documentsDirectory: docs, keyVault: vault);
      await storage.saveConversations([
        Conversation.mainChannel(model: 'hermes-agent')
            .addMessage(Message.user(content: text)),
      ]);
      return encFile().readAsStringSync();
    }

    test('keystore entry missing: old history is kept, not overwritten',
        () async {
      final original = await saveOne(_MemoryVault(), 'precious history');

      // Same files, but the keystore lost its entry.
      final fresh = _MemoryVault();
      final storage =
          LocalConversationStorage(documentsDirectory: docs, keyVault: fresh);
      expect(await storage.loadConversations(), isEmpty);
      await storage.saveConversations([
        Conversation.mainChannel(model: 'hermes-agent')
            .addMessage(Message.user(content: 'new chat')),
      ]);

      final kept = setAside();
      expect(kept, hasLength(1));
      expect(kept.single.readAsStringSync(), original);
    });

    test('wrong key: unreadable history is kept before the next save',
        () async {
      final original = await saveOne(_MemoryVault(), 'precious history');

      final other = _MemoryVault();
      await saveOne(other, 'throwaway'); // file now under a second key
      final secondCopy = encFile().readAsStringSync();
      // Put the first file back, readable only with the first key.
      encFile().writeAsStringSync(original);

      final storage =
          LocalConversationStorage(documentsDirectory: docs, keyVault: other);
      expect(await storage.loadConversations(), isEmpty);
      await storage.saveConversations([
        Conversation.mainChannel(model: 'hermes-agent')
            .addMessage(Message.user(content: 'new chat')),
      ]);

      expect(secondCopy, isNot(original));
      expect(setAside().map((f) => f.readAsStringSync()), contains(original));
    });

    test('keystore read error: no new key is generated', () async {
      await saveOne(_MemoryVault(), 'precious history');
      final before = encFile().readAsStringSync();

      final broken = _ThrowingVault();
      final storage =
          LocalConversationStorage(documentsDirectory: docs, keyVault: broken);
      await expectLater(
        storage.saveConversations([
          Conversation.mainChannel(model: 'hermes-agent')
              .addMessage(Message.user(content: 'new chat')),
        ]),
        throwsA(isA<StateError>()),
      );

      expect(broken.writes, 0);
      expect(encFile().readAsStringSync(), before);
    });

    test('clearAll also deletes set-aside history', () async {
      await saveOne(_MemoryVault(), 'precious history');
      final storage = LocalConversationStorage(
          documentsDirectory: docs, keyVault: _MemoryVault());
      await storage.loadConversations();
      expect(setAside(), isNotEmpty);

      await storage.clearAll();

      expect(setAside(), isEmpty);
      expect(await storage.listExistingConversationDataPaths(), isEmpty);
    });
  });

  group('save failures are reported (#894)', () {
    Future<Directory> docs() async => tempDir;

    test('saveConversations throws when the key cannot be stored', () async {
      final storage = LocalConversationStorage(
        documentsDirectory: docs,
        keyVault: _NoWriteVault(),
      );
      await expectLater(
        storage.saveConversations([
          Conversation.mainChannel(model: 'hermes-agent')
              .addMessage(Message.user(content: 'hello')),
        ]),
        throwsA(isA<StateError>()),
      );
    });

    test('a failed migration keeps the plaintext legacy file', () async {
      final dir = Directory('${tempDir.path}/Pistisai')
        ..createSync(recursive: true);
      final legacy = File('${dir.path}/conversations.json');
      final conv = Conversation.mainChannel(model: 'hermes-agent')
          .addMessage(Message.user(content: 'only copy'));
      legacy.writeAsStringSync(jsonEncode([conv.toJson()]));

      final storage = LocalConversationStorage(
        documentsDirectory: docs,
        keyVault: _NoWriteVault(),
      );
      await storage.loadConversations();

      expect(legacy.existsSync(), isTrue,
          reason: 'the only copy must not be deleted when saving failed');
    });
  });
}

class _ThrowingVault implements LocalBrainKeyVault {
  int writes = 0;

  @override
  Future<String?> read(String key) async =>
      throw const FileSystemException('keyring locked');

  @override
  Future<void> write(String key, String value) async {
    writes++;
  }

  @override
  Future<void> delete(String key) async {}
}

class _NoWriteVault implements LocalBrainKeyVault {
  @override
  Future<String?> read(String key) async => null;

  @override
  Future<void> write(String key, String value) async =>
      throw const FileSystemException('no keyring');

  @override
  Future<void> delete(String key) async {}
}
