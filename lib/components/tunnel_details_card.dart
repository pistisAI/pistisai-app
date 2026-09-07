import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/tunnel_state.dart';
import '../config/theme.dart';

class TunnelDetailsCard extends StatelessWidget {
  final TunnelState tunnelState;

  const TunnelDetailsCard({super.key, required this.tunnelState});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildConnectionStats(context),
        const SizedBox(height: 16),
        _buildTechnicalInfo(context),
      ],
    );
  }

  Widget _buildConnectionStats(BuildContext context) {
    final stats = tunnelState.stats;
    final quality = tunnelState.quality;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Connection Details',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        // shrinkWrap: true is intentional — this is a small fixed grid (6 items, 3 rows)
        // embedded in a Column, not a scrollable list. No lazy loading needed.
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 3,
          children: [
            _buildStatItem(context, 'Status',
                tunnelState.isConnected ? 'Connected' : 'Disconnected'),
            _buildStatItem(context, 'Quality', quality.label,
                color: _getQualityColor(context, quality)),
            _buildStatItem(context,
                'Duration', _formatDuration(tunnelState.connectionDuration)),
            _buildStatItem(context, 'Latency',
                stats != null ? '${stats.averageLatencyMs} ms' : 'N/A'),
            _buildStatItem(context, 'Transferred',
                stats != null ? _formatBytes(stats.bytesTransferred) : 'N/A'),
            _buildStatItem(context, 'Received',
                stats != null ? _formatBytes(stats.bytesReceived) : 'N/A'),
            _buildStatItem(context,
                'Success Rate',
                stats != null
                    ? '${(stats.successRate * 100).toStringAsFixed(1)}%'
                    : 'N/A'),
          ],
        ),
      ],
    );
  }

  Widget _buildTechnicalInfo(BuildContext context) {
    return ExpansionTile(
      title: const Text(
        'Technical Info',
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
      ),
      children: [
        _buildInfoRow(context, 'Tunnel ID', tunnelState.tunnelId ?? 'N/A'),
        _buildInfoRow(context,
            'Tunnel Port', tunnelState.tunnelPort?.toString() ?? 'N/A'),
        _buildInfoRow(context,
            'Last Request',
            tunnelState.stats != null
                ? DateFormat.yMd()
                    .add_Hms()
                    .format(tunnelState.stats!.lastRequestAt)
                : 'N/A'),
      ],
    );
  }

  Widget _buildStatItem(BuildContext context, String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(color: AppTheme.colorsOf(context).textColorLight, fontSize: 12)),
          Text(value,
              style: TextStyle(
                  color: color ?? AppTheme.colorsOf(context).textColor,
                  fontSize: 14,
                  fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildInfoRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: AppTheme.colorsOf(context).textColorLight)),
          Text(value, style: const TextStyle(fontFamily: 'monospace')),
        ],
      ),
    );
  }

  Color _getQualityColor(BuildContext context, TunnelConnectionQuality quality) {
    switch (quality) {
      case TunnelConnectionQuality.excellent:
        return Colors.green;
      case TunnelConnectionQuality.good:
        return Colors.lightGreen;
      case TunnelConnectionQuality.fair:
        return Colors.orange;
      case TunnelConnectionQuality.poor:
        return Colors.red;
      default:
        return AppTheme.colorsOf(context).textColor;
    }
  }

  String _formatDuration(Duration? duration) {
    if (duration == null) return 'N/A';
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = twoDigits(duration.inHours);
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$hours:$minutes:$seconds';
  }

  String _formatBytes(double bytes) {
    if (bytes < 1024) {
      return '${bytes.toStringAsFixed(2)} B';
    }
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(2)} KB';
    }
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }
}
