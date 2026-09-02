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

  test('main-channel survives a new storage instance without a keyring', () async {
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
    expect(
      File('${tempDir.path}/Pistisai/.conversation_key').existsSync(),
      isTrue,
    );
  });

  test('Conversation.mainChannel always uses the stable session id', () {
    expect(Conversation.mainChannel().id, 'main-channel');
    expect(Conversation.mainChannel(model: 'hermes-agent').id, 'main-channel');
  });
}
