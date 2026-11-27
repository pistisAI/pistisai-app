import 'package:flutter/foundation.dart';

/// Who wrote a [HarnessMessage].
enum HarnessRole { user, assistant, system, tool }

/// One message of a channel's history as a harness reports it.
@immutable
class HarnessMessage {
  HarnessMessage({
    required this.id,
    required this.role,
    required this.content,
    required DateTime createdAt,
  }) : createdAt = createdAt.toUtc();

  /// Id given by the harness; unique within one channel.
  final String id;
  final HarnessRole role;
  final String content;
  final DateTime createdAt;

  @override
  bool operator ==(Object other) =>
      other is HarnessMessage &&
      other.id == id &&
      other.role == role &&
      other.content == content &&
      other.createdAt == createdAt;

  @override
  int get hashCode => Object.hash(id, role, content, createdAt);
}

/// A typed event a harness adapter emits for one channel (#1066, #1068).
///
/// Adapters translate their runtime's own wire format into these, so the chat
/// layer does not depend on any one harness.
@immutable
sealed class HarnessEvent {
  const HarnessEvent({required this.channelId});

  final String channelId;
}

/// A piece of assistant text that is still being written.
final class HarnessDelta extends HarnessEvent {
  const HarnessDelta({
    required super.channelId,
    required this.messageId,
    required this.text,
  });

  final String messageId;

  /// Only the new text, not the whole message so far.
  final String text;
}

/// A message is complete and can be stored as final.
final class HarnessMessageCompleted extends HarnessEvent {
  const HarnessMessageCompleted({
    required super.channelId,
    required this.message,
  });

  final HarnessMessage message;
}

/// The agent started a tool call.
final class HarnessToolStarted extends HarnessEvent {
  const HarnessToolStarted({
    required super.channelId,
    required this.toolCallId,
    required this.toolName,
  });

  final String toolCallId;
  final String toolName;
}

/// A tool call ended, successfully or not.
final class HarnessToolFinished extends HarnessEvent {
  const HarnessToolFinished({
    required super.channelId,
    required this.toolCallId,
    required this.toolName,
    this.failed = false,
  });

  final String toolCallId;
  final String toolName;
  final bool failed;
}

/// The harness could not do what was asked.
final class HarnessError extends HarnessEvent {
  const HarnessError({
    required super.channelId,
    required this.message,
    this.retryable = false,
  });

  final String message;
  final bool retryable;
}
