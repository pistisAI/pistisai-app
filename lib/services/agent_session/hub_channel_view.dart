import 'dart:convert';

import '../../models/conversation.dart';

/// JSON other devices read from the hub. Runtime session ids are omitted:
/// they belong to the harness adapter, not to the channel (#1067).
Map<String, Object?> hubChannelSummary(Conversation conversation) {
  return <String, Object?>{
    'id': conversation.channelId,
    'kind': conversation.channel.kind.name,
    'title': conversation.title,
    'createdAt': conversation.createdAt.toUtc().toIso8601String(),
    'updatedAt': conversation.updatedAt.toUtc().toIso8601String(),
    'messageCount': conversation.messages.length,
  };
}

Map<String, Object?> hubChannelDetail(Conversation conversation) {
  return <String, Object?>{
    'channel': hubChannelSummary(conversation),
    'messages': [
      for (final message in conversation.messages) message.toJson(),
    ],
  };
}

String hubChannelListBody(List<Conversation> conversations) {
  return jsonEncode(<String, Object?>{
    'channels': [
      for (final conversation in conversations) hubChannelSummary(conversation),
    ],
  });
}
