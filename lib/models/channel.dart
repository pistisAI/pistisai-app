library;

/// Gateway communication channel model
///
/// Represents a channel reported by the connected agent gateway. Fields the
/// gateway does not report stay `null` so the UI can hide them instead of
/// showing invented values (AGENTS.md: "Controls tell the truth", #859).
class GatewayChannel {
  /// Unique identifier for the channel
  final String id;

  /// Display name of the channel
  final String name;

  /// Optional description of the channel's purpose
  final String? description;

  /// The platform/type backing this channel (e.g. 'gateway', 'telegram')
  final String? platform;

  /// Total number of messages in this channel, or `null` when not reported
  final int? messageCount;

  /// Timestamp of the last activity in this channel
  final DateTime? lastActivity;

  /// Number of unread messages, or `null` when not reported
  final int? unreadCount;

  /// Whether the gateway reports this channel as connected/running, or `null`
  /// when the gateway does not say
  final bool? connected;

  /// Whether this is the gateway's current (active) profile
  final bool isCurrent;

  const GatewayChannel({
    required this.id,
    required this.name,
    this.description,
    this.platform,
    this.messageCount,
    this.lastActivity,
    this.unreadCount,
    this.connected,
    this.isCurrent = false,
  });

  /// Creates a GatewayChannel from JSON data
  factory GatewayChannel.fromJson(Map<String, dynamic> json) {
    return GatewayChannel(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      platform: json['platform'] as String?,
      messageCount: json['messageCount'] as int?,
      lastActivity: json['lastActivity'] != null
          ? DateTime.parse(json['lastActivity'] as String)
          : null,
      unreadCount: json['unreadCount'] as int?,
      connected: json['connected'] as bool?,
      isCurrent: json['isCurrent'] as bool? ?? false,
    );
  }
}
