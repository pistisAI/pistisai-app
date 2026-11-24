library;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/channel.dart';
import '../../services/channel_service.dart';
import '../../di/locator.dart' as di;
import '../../l10n/app_localizations.dart';
import '../../widgets/common/refreshable_screen.dart';
import '../../widgets/common/status_badge.dart';
import '../../config/theme.dart';

/// Screen displaying detailed information about a specific gateway channel.
///
/// Shows only what the gateway reported for the channel. Per-channel controls
/// are not wired to the runtime yet, so they are shown disabled and labelled
/// "not available yet" instead of reporting a fake success (#859).
class ChannelDetailScreen extends StatefulWidget {
  final String channelId;

  const ChannelDetailScreen({super.key, required this.channelId});

  @override
  State<ChannelDetailScreen> createState() => _ChannelDetailScreenState();
}

class _ChannelDetailScreenState extends State<ChannelDetailScreen> {
  late Future<GatewayChannel?> _channelFuture;

  String get channelId => widget.channelId;

  @override
  void initState() {
    super.initState();
    _channelFuture = _loadChannel();
  }

  Future<void> _reload() async {
    final future = _loadChannel();
    setState(() {
      _channelFuture = future;
    });
    await future;
  }

  /// Load the channel data from the service.
  Future<GatewayChannel?> _loadChannel() async {
    try {
      final service = di.serviceLocator<ChannelService>();
      final channels = await service.listChannels();
      for (final c in channels) {
        if (c.id == channelId) return c;
      }
      return null;
    } catch (e) {
      debugPrint('Error loading channel $channelId: $e');
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.channelDetailsTitle),
      ),
      body: FutureBuilder<GatewayChannel?>(
        future: _channelFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError || snapshot.data == null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline,
                      size: 64, color: AppTheme.colorsOf(context).danger),
                  const SizedBox(height: 16),
                  Text(l10n.channelNotFound),
                  if (snapshot.hasError) ...[
                    const SizedBox(height: 8),
                    Text('${snapshot.error}',
                        style: theme.textTheme.bodySmall),
                  ],
                ],
              ),
            );
          }

          final channel = snapshot.data!;

          return RefreshableScreen(
            onRefresh: _reload,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Channel Header Card
                  Card(
                    margin: const EdgeInsets.only(bottom: 20),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 24,
                                backgroundColor:
                                    theme.colorScheme.primaryContainer,
                                child: Icon(
                                  _getChannelIcon(channel.name),
                                  color: theme.colorScheme.onPrimaryContainer,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      channel.name,
                                      style:
                                          theme.textTheme.titleLarge?.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    if (_description(l10n, channel) != null)
                                      Text(
                                        _description(l10n, channel)!,
                                        style: theme.textTheme.bodyMedium
                                            ?.copyWith(
                                          color: theme.colorScheme.onSurface
                                              .withValues(alpha: 0.6),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              if (channel.connected != null)
                                StatusBadge(
                                  status: channel.connected!
                                      ? StatusType.running
                                      : StatusType.stopped,
                                  label: channel.connected!
                                      ? l10n.commonConnected
                                      : l10n.commonDisconnected,
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Channel Statistics Section
                  Text(
                    l10n.channelStatistics,
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      if (channel.messageCount != null)
                        _StatCard(
                          label: l10n.channelMessages,
                          value: '${channel.messageCount}',
                          icon: Icons.message,
                          theme: theme,
                        ),
                      _StatCard(
                        label: l10n.channelPlatform,
                        value: channel.platform ?? l10n.channelPlatformUnknown,
                        icon: Icons.language,
                        theme: theme,
                      ),
                      if (channel.lastActivity != null)
                        _StatCard(
                          label: l10n.channelLastActivity,
                          value:
                              _formatLastActivity(l10n, channel.lastActivity!),
                          icon: Icons.access_time,
                          theme: theme,
                        ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Channel Controls Section
                  Text(
                    l10n.channelControls,
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    l10n.channelControlsNotAvailable,
                    key: const Key('channel_controls_not_available'),
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: 8),
                  Card(
                    child: Column(
                      children: [
                        _UnavailableAction(
                          icon: Icons.play_arrow,
                          title: l10n.channelStart,
                          subtitle: l10n.channelActionNotAvailable,
                        ),
                        const Divider(),
                        _UnavailableAction(
                          icon: Icons.stop,
                          title: l10n.channelStop,
                          subtitle: l10n.channelActionNotAvailable,
                        ),
                        const Divider(),
                        _UnavailableAction(
                          icon: Icons.refresh,
                          title: l10n.channelReconnect,
                          subtitle: l10n.channelActionNotAvailable,
                        ),
                        const Divider(),
                        _UnavailableAction(
                          icon: Icons.description,
                          title: l10n.channelViewLogs,
                          subtitle: l10n.channelActionNotAvailable,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  String? _description(AppLocalizations l10n, GatewayChannel channel) {
    if (channel.description != null) return channel.description;
    if (channel.platform != 'gateway') return null;
    return channel.isCurrent
        ? l10n.channelGatewayProfileCurrent
        : l10n.channelGatewayProfile;
  }

  IconData _getChannelIcon(String channelName) {
    final name = channelName.toLowerCase();
    if (name.contains('main') || name.contains('primary')) {
      return Icons.chat_bubble;
    } else if (name.contains('agent') || name.contains('event')) {
      return Icons.smart_toy;
    } else if (name.contains('system') || name.contains('monitor')) {
      return Icons.monitor_heart;
    } else if (name.contains('debug') || name.contains('log')) {
      return Icons.bug_report;
    } else if (name.contains('notification') || name.contains('alert')) {
      return Icons.notifications;
    } else {
      return Icons.tag;
    }
  }

  String _formatLastActivity(AppLocalizations l10n, DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);
    if (difference.inMinutes < 1) {
      return l10n.channelJustNow;
    } else if (difference.inMinutes < 60) {
      return l10n.channelMinutesAgo(difference.inMinutes);
    } else if (difference.inHours < 24) {
      return l10n.channelHoursAgo(difference.inHours);
    } else if (difference.inDays < 7) {
      return l10n.channelDaysAgo(difference.inDays);
    } else {
      return DateFormat('MMM d, y').format(timestamp);
    }
  }
}

/// A channel control that is not wired to the runtime yet: shown disabled
/// with a "not available yet" subtitle so it never reports a fake success.
class _UnavailableAction extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _UnavailableAction({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      enabled: false,
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final ThemeData theme;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: (MediaQuery.of(context).size.width - 64) / 3,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: theme.colorScheme.onSurfaceVariant, size: 20),
          const SizedBox(height: 8),
          Text(label, style: theme.textTheme.labelSmall),
          Text(
            value,
            style: theme.textTheme.bodyMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
