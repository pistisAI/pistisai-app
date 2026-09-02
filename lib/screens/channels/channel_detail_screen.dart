library;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/channel.dart';
import '../../services/channel_service.dart';
import '../../di/locator.dart' as di;
import '../../widgets/common/refreshable_screen.dart';
import '../../widgets/common/status_badge.dart';

/// Screen displaying detailed information about a specific gateway channel.
class ChannelDetailScreen extends StatelessWidget {
  final String channelId;

  const ChannelDetailScreen({super.key, required this.channelId});

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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Channel Details'),
      ),
      body: FutureBuilder<GatewayChannel?>(
        future: _loadChannel(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError || snapshot.data == null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  const Text('Channel not found'),
                  const SizedBox(height: 8),
                  Text('${snapshot.error}', style: theme.textTheme.bodySmall),
                ],
              ),
            );
          }

          final channel = snapshot.data!;

          return RefreshableScreen(
            onRefresh: () async {
              // In a real implementation, this would trigger a data reload.
            },
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
                                backgroundColor: theme.colorScheme.primaryContainer,
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
                                      style: theme.textTheme.titleLarge?.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    if (channel.description != null)
                                      Text(
                                        channel.description!,
                                        style: theme.textTheme.bodyMedium?.copyWith(
                                          color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              StatusBadge(
                                status: channel.unreadCount > 0
                                    ? StatusType.active
                                    : StatusType.idle,
                                label: channel.unreadCount > 0 ? 'New' : 'Read',
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Channel Statistics Section
                  Text(
                    'Statistics',
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _StatCard(
                        label: 'Messages',
                        value: '${channel.messageCount}',
                        icon: Icons.message,
                        theme: theme,
                      ),
                      _StatCard(
                        label: 'Platform',
                        value: channel.platform ?? 'Unknown',
                        icon: Icons.language,
                        theme: theme,
                      ),
                      _StatCard(
                        label: 'Last Activity',
                        value: channel.lastActivity != null
                            ? _formatLastActivity(channel.lastActivity!)
                            : 'Never',
                        icon: Icons.access_time,
                        theme: theme,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Channel Controls Section
                  Text(
                    'Controls',
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 12),
                  Card(
                    child: Column(
                      children: [
                        ListTile(
                          leading: const Icon(Icons.play_arrow),
                          title: const Text('Start Channel'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => _handleAction(context, 'start'),
                        ),
                        const Divider(),
                        ListTile(
                          leading: const Icon(Icons.stop),
                          title: const Text('Stop Channel'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => _handleAction(context, 'stop'),
                        ),
                        const Divider(),
                        ListTile(
                          leading: const Icon(Icons.refresh),
                          title: const Text('Reconnect'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => _handleAction(context, 'reconnect'),
                        ),
                        const Divider(),
                        ListTile(
                          leading: const Icon(Icons.description),
                          title: const Text('View Logs'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => _handleAction(context, 'logs'),
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

  void _handleAction(BuildContext context, String action) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Action $action performed for channel $channelId')),
    );
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

  String _formatLastActivity(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);
    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return DateFormat('MMM d, y').format(timestamp);
    }
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
            style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
