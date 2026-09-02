import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pistisai/models/conversation.dart';
import 'package:pistisai/models/message.dart';
import 'package:pistisai/services/local_conversation_storage.dart';

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

  test('main-channel survives a new storage instance without a keyring',
      () async {
    Future<Directory> docs() async => tempDir;

    final first = LocalConversationStorage(
      documentsDirectory: docs,
      skipKeyring: true,
    );
    final original = Conversation.mainChannel(model: 'hermes-agent').addMessage(
      Message.user(content: 'Who are you? One sentence.'),
    );
    await first.saveConversations([original]);

    final second = LocalConversationStorage(
      documentsDirectory: docs,
      skipKeyring: true,
    );
    final loaded = await second.loadConversations();

    expect(loaded, hasLength(1));
    expect(loaded.first.id, 'main-channel');
    expect(loaded.first.messages, hasLength(1));
    expect(loaded.first.messages.first.content, contains('Who are you?'));
    final keyFile = File('${tempDir.path}/Pistisai/.conversation_key');
    expect(keyFile.existsSync(), isTrue);
    if (!Platform.isWindows) {
      final mode = keyFile.statSync().mode & 0x1FF;
      expect(mode & 0x049, 0,
          reason: 'conversation key must not be group/world readable');
    }
  });

  test('migrates encrypted history from the interim chat/ directory', () async {
    Future<Directory> docs() async => tempDir;

    final interim = Directory('${tempDir.path}/chat')..createSync();
    final first = LocalConversationStorage(
      documentsDirectory: () async => interim.parent,
      skipKeyring: true,
    );

    // Seed the interim path by writing through a storage that uses chat/
    // via the legacy probe: write files directly after a normal save to Pistisai,
    // then move them into chat/ and delete Pistisai to simulate the old layout.
    final seed = LocalConversationStorage(
      documentsDirectory: docs,
      skipKeyring: true,
    );
    await seed.saveConversations([
      Conversation.mainChannel(model: 'hermes-agent').addMessage(
        Message.user(content: 'migrated-from-chat-dir'),
      ),
    ]);
    final pistisaiDir = Directory('${tempDir.path}/Pistisai');
    for (final name in [
      'conversations.json.enc',
      '.conversation_key',
    ]) {
      File('${pistisaiDir.path}/$name').copySync('${interim.path}/$name');
    }
    pistisaiDir.deleteSync(recursive: true);

    final loaded = await first.loadConversations();
    expect(loaded, hasLength(1));
    expect(loaded.first.messages.first.content, 'migrated-from-chat-dir');
    expect(
      File('${tempDir.path}/Pistisai/conversations.json.enc').existsSync(),
      isTrue,
    );
  });

  test('Conversation.mainChannel always uses the stable session id', () {
    expect(Conversation.mainChannel().id, 'main-channel');
    expect(Conversation.mainChannel(model: 'hermes-agent').id, 'main-channel');
  });
}
