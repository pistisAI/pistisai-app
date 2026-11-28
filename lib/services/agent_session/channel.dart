import 'package:flutter/foundation.dart';

/// What a conversation channel is for (#1067).
enum ChannelKind {
  /// The one-to-one conversation between the person and their agent.
  direct,

  /// A conversation scoped to a project or topic.
  topic,
}

/// A conversation channel: the stable identity of a conversation, owned by
/// the hub's local store (#1067).
///
/// A channel does not belong to an agent harness. The harness that answers in
/// it can change; the channel id, and the history stored under it, stay the
/// same. Runtime session ids of a harness are kept apart, in
/// `RuntimeSessionMap`.
///
/// Not to be confused with `GatewayChannel` (`lib/models/channel.dart`), which
/// lists the messaging platforms connected to the Hermes gateway.
///
/// Each `Conversation` has one (`Conversation.channel`); the single
/// `pistisai` conversation is the default `direct` channel.
@immutable
class ConversationChannel {
  ConversationChannel({
    required this.id,
    required this.kind,
    required this.title,
    required DateTime createdAt,
  }) : createdAt = createdAt.toUtc() {
    if (id.trim().isEmpty) {
      throw ArgumentError.value(id, 'id', 'must not be empty');
    }
  }

  /// Stable id. Never a runtime session id.
  final String id;
  final ChannelKind kind;
  final String title;

  /// Creation time, always stored in UTC.
  final DateTime createdAt;

  ConversationChannel copyWith({String? title}) {
    return ConversationChannel(
      id: id,
      kind: kind,
      title: title ?? this.title,
      createdAt: createdAt,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
        'id': id,
        'kind': kind.name,
        'title': title,
        'createdAt': createdAt.toIso8601String(),
      };

  /// Reads a channel written by [toJson]. Throws [FormatException] on a
  /// missing or mistyped field rather than inventing a value.
  factory ConversationChannel.fromJson(Map<String, Object?> json) {
    final id = json['id'];
    final kindName = json['kind'];
    final title = json['title'];
    final createdAt = json['createdAt'];
    if (id is! String || id.trim().isEmpty) {
      throw const FormatException('channel: missing id');
    }
    if (title is! String) {
      throw const FormatException('channel: missing title');
    }
    if (createdAt is! String) {
      throw const FormatException('channel: missing createdAt');
    }
    final kind = ChannelKind.values.where((k) => k.name == kindName);
    if (kind.isEmpty) {
      throw FormatException('channel: unknown kind', kindName);
    }
    final parsed = DateTime.tryParse(createdAt);
    if (parsed == null) {
      throw FormatException('channel: bad createdAt', createdAt);
    }
    return ConversationChannel(
      id: id,
      kind: kind.first,
      title: title,
      createdAt: parsed,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is ConversationChannel &&
      other.id == id &&
      other.kind == kind &&
      other.title == title &&
      other.createdAt == createdAt;

  @override
  int get hashCode => Object.hash(id, kind, title, createdAt);

  @override
  String toString() => 'ConversationChannel($id, ${kind.name})';
}
