library;

/// A Hermes session, as listed by `hermes sessions list`.
///
/// The CLI gives a title, a preview of the last message, how long ago the
/// session was active and its id. Fields the CLI does not provide are null
/// and the screen does not show them.
class SessionData {
  /// Unique identifier for the session
  final String id;

  /// Session type: `agent` or `cron` (ids starting with `cron_`).
  final String type;

  /// Session title (user or agent name)
  final String userOrAgent;

  /// Preview of the last message, when the CLI shows one.
  final String? preview;

  /// "Last active" as printed by the CLI (for example `5m ago`).
  final String? lastActive;

  /// Session start timestamp, when known.
  final DateTime? startTime;

  /// Total tokens used in this session, when known.
  final int? tokenUsage;

  /// Number of messages exchanged, when known.
  final int? messageCount;

  /// Current session status, when known.
  final String? status;

  const SessionData({
    required this.id,
    required this.type,
    required this.userOrAgent,
    this.preview,
    this.lastActive,
    this.startTime,
    this.tokenUsage,
    this.messageCount,
    this.status,
  });

  /// Duration since [startTime], or null when the start is unknown.
  Duration? get duration =>
      startTime == null ? null : DateTime.now().difference(startTime!);
}
