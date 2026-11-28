import '../../brand/brand_copy.dart';
import '../../models/conversation.dart';
import 'channel.dart';

/// What a typed chat command does to a hub channel (#1067).
enum ChannelCommand {
  none,
  newChannel,
  resetChannel,
}

/// `/new` starts another channel. `/reset` asks the harness to forget its
/// runtime session for the current channel. Anything else is a normal turn.
ChannelCommand channelCommandFor(String text) {
  switch (text.trim()) {
    case '/new':
      return ChannelCommand.newChannel;
    case '/reset':
      return ChannelCommand.resetChannel;
    default:
      return ChannelCommand.none;
  }
}

/// A new topic channel. Its id is created locally and is not a runtime
/// session id.
Conversation newTopicChannel({String? model}) {
  final created = Conversation.create(
    title: BrandCopy.newChannelTitle,
    model: model,
  );
  return created.copyWith(
    channel: ConversationChannel(
      id: created.id,
      kind: ChannelKind.topic,
      title: created.title,
      createdAt: created.createdAt,
    ),
  );
}
