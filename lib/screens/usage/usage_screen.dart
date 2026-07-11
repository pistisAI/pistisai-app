import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../widgets/usage/metric_card.dart';
import '../../widgets/navigation/popout_button.dart';

import 'package:pistisai/services/rate_limit_manager.dart';
import 'package:pistisai/database/drift_local_brain.dart';

enum TimeRange { today, week, month }

class UsageScreen extends StatefulWidget {
  const UsageScreen({super.key});

  @override
  State<UsageScreen> createState() => _UsageScreenState();
}

class _UsageScreenState extends State<UsageScreen> {
  TimeRange _selectedTimeRange = TimeRange.today;

  late final RateLimitManager _rateLimitManager;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _rateLimitManager = context.read<RateLimitManager>();
  }

  Future<void> _onRefresh() async {
    // Capacities are streamed live via RateLimitManager; refresh triggers a
    // re-read of the underlying Drift stream through a state bump.
    setState(() {});
  }

  void _onTimeRangeChanged(Set<TimeRange> newSelection) {
    if (newSelection.isNotEmpty) {
      setState(() {
        _selectedTimeRange = newSelection.first;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Usage'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _onRefresh,
            tooltip: 'Refresh',
          ),
          const PopOutButton(
            sectionName: 'usage',
            branchIndex: 5,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _onRefresh,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Time range selector
              Center(
                child: SegmentedButton<TimeRange>(
                  segments: const [
                    ButtonSegment(
                      value: TimeRange.today,
                      label: Text('Today'),
                      icon: Icon(Icons.today),
                    ),
                    ButtonSegment(
                      value: TimeRange.week,
                      label: Text('Week'),
                      icon: Icon(Icons.date_range),
                    ),
                    ButtonSegment(
                      value: TimeRange.month,
                      label: Text('Month'),
                      icon: Icon(Icons.calendar_month),
                    ),
                  ],
                  selected: {_selectedTimeRange},
                  onSelectionChanged: _onTimeRangeChanged,
                ),
              ),
              const SizedBox(height: 24),

                        // Concurrency / active requests Card (real capacity data)
                        StreamBuilder<List<ModelCapacityData>>(
                          stream: _rateLimitManager.watchCapacities(),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState ==
                                ConnectionState.waiting) {
                              return const SizedBox();
                            } else if (snapshot.hasError) {
                              return Text('Error: ${snapshot.error}');
                            } else {
                              final capacities = snapshot.data!;
                              final totalUsed = capacities.fold(
                                  0,
                                  (sum, c) =>
                                      sum + c.concurrentUsed);
                              final totalLimit = capacities.fold(
                                  0,
                                  (sum, c) =>
                                      sum + c.concurrentLimit);
                              final utilization = totalLimit > 0
                                  ? totalUsed / totalLimit
                                  : 0.0;

                              return MetricCard(
                                title: 'Active Concurrency',
                                icon: Icons.sync,
                                value: '$totalUsed',
                                unit: 'of $totalLimit',
                                subtitle: 'Concurrent requests in flight',
                                trend: utilization > 0.8
                                    ? MetricTrend.up
                                    : MetricTrend.neutral,
                                progressValue: utilization,
                                progressLabel: 'Concurrency utilization',
                                child: _buildConcurrencyBreakdown(
                                    theme, capacities),
                              );
                            }
                          },
                        ),
                        const SizedBox(height: 16),

                        // Requests-per-minute Card (real capacity data)
                        StreamBuilder<List<ModelCapacityData>>(
                          stream: _rateLimitManager.watchCapacities(),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState ==
                                ConnectionState.waiting) {
                              return const SizedBox();
                            } else if (snapshot.hasError) {
                              return Text('Error: ${snapshot.error}');
                            } else {
                              final capacities = snapshot.data!;
                              final totalRpm = capacities.fold(
                                  0, (sum, c) => sum + c.rpmUsed);
                              final totalRpmLimit = capacities.fold(
                                  0,
                                  (sum, c) =>
                                      sum + (c.rpmLimit ?? 0));
                              final rpmUtil = totalRpmLimit > 0
                                  ? totalRpm / totalRpmLimit
                                  : 0.0;

                              return MetricCard(
                                title: 'Request Rate',
                                icon: Icons.api,
                                value: '$totalRpm',
                                unit: 'req/min',
                                subtitle: 'Requests per minute across models',
                                trend: MetricTrend.neutral,
                                progressValue: rpmUtil,
                                progressLabel: 'RPM utilization',
                                child: _buildRpmBreakdown(
                                    theme, capacities),
                              );
                            }
                          },
                        ),
                        const SizedBox(height: 16),

                        // Tokens-per-minute Card (real capacity data)
                        StreamBuilder<List<ModelCapacityData>>(
                          stream: _rateLimitManager.watchCapacities(),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState ==
                                ConnectionState.waiting) {
                              return const SizedBox();
                            } else if (snapshot.hasError) {
                              return Text('Error: ${snapshot.error}');
                            } else {
                              final capacities = snapshot.data!;
                              final totalTpm = capacities.fold(
                                  0, (sum, c) => sum + c.tpmUsed);
                              final totalTpmLimit = capacities.fold(
                                  0,
                                  (sum, c) =>
                                      sum + (c.tpmLimit ?? 0));
                              final tpmUtil = totalTpmLimit > 0
                                  ? totalTpm / totalTpmLimit
                                  : 0.0;

                              return MetricCard(
                                title: 'Token Rate',
                                icon: Icons.token,
                                value: _formatTokenValue(totalTpm),
                                unit: 'tok/min',
                                subtitle: 'Tokens per minute across models',
                                trend: MetricTrend.neutral,
                                progressValue: tpmUtil,
                                progressLabel: 'TPM utilization',
                                child: _buildTpmBreakdown(
                                    theme, capacities),
                              );
                            }
                          },
                        ),

                        const SizedBox(height: 24),

                        // Chart placeholders
                        _buildChartPlaceholder('Token Usage Over Time'),
                        const SizedBox(height: 16),
                        _buildChartPlaceholder('Request Volume'),
                        const SizedBox(height: 16),
                        _buildChartPlaceholder('Resource Trends'),
                      ],
                    ),
                  ),
      ),
    );
  }

  String _formatTokenValue(int tokens) {
    if (tokens >= 1000000) {
      return '${(tokens / 1000000).toStringAsFixed(1)}M';
    } else if (tokens >= 1000) {
      return '${(tokens / 1000).toStringAsFixed(1)}K';
    } else {
      return tokens.toString();
    }
  }

  Widget _buildConcurrencyBreakdown(
      ThemeData theme, List<ModelCapacityData> capacities) {
    if (capacities.isEmpty) {
      return _buildEmptyRow(theme, 'No active models');
    }
    final top = capacities
        .where((c) => c.concurrentLimit > 0)
        .toList()
      ..sort((a, b) => b.concurrentUsed.compareTo(a.concurrentUsed));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Text(
          'Per-model concurrency',
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
          ),
        ),
        const SizedBox(height: 4),
        for (final c in top.take(4))
          _buildMetricRow(
            c.displayName ?? c.modelId,
            '${c.concurrentUsed}/${c.concurrentLimit}',
            Icons.sync,
            theme.colorScheme.primary,
            theme,
          ),
      ],
    );
  }

  Widget _buildRpmBreakdown(
      ThemeData theme, List<ModelCapacityData> capacities) {
    if (capacities.isEmpty) {
      return _buildEmptyRow(theme, 'No rate data');
    }
    final withLimit = capacities.where((c) => c.rpmLimit != null).toList()
      ..sort((a, b) => b.rpmUsed.compareTo(a.rpmUsed));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Text(
          'Top models by RPM',
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
          ),
        ),
        const SizedBox(height: 4),
        for (final c in withLimit.take(4))
          _buildMetricRow(
            c.displayName ?? c.modelId,
            '${c.rpmUsed}/${c.rpmLimit}',
            Icons.api,
            theme.colorScheme.primary,
            theme,
          ),
      ],
    );
  }

  Widget _buildTpmBreakdown(
      ThemeData theme, List<ModelCapacityData> capacities) {
    if (capacities.isEmpty) {
      return _buildEmptyRow(theme, 'No token data');
    }
    final withLimit = capacities.where((c) => c.tpmLimit != null).toList()
      ..sort((a, b) => b.tpmUsed.compareTo(a.tpmUsed));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Text(
          'Top models by TPM',
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
          ),
        ),
        const SizedBox(height: 4),
        for (final c in withLimit.take(4))
          _buildMetricRow(
            c.displayName ?? c.modelId,
            '${_formatTokenValue(c.tpmUsed)}/${_formatTokenValue(c.tpmLimit!)}',
            Icons.token,
            theme.colorScheme.primary,
            theme,
          ),
      ],
    );
  }

  Widget _buildEmptyRow(ThemeData theme, String message) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Text(
        message,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
        ),
      ),
    );
  }

  Widget _buildMetricRow(
      String label, String value, IconData icon, Color color, ThemeData theme) {
    return Row(
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 6),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildChartPlaceholder(String title) {
    final theme = Theme.of(context);

    return Card(
      child: Container(
        height: 200,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.show_chart,
                      size: 48,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Chart placeholder',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color:
                            theme.colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // NOTE: Per-user request success/latency/CPU metrics have no backend
  // endpoint or client data source yet. The cards above use real
  // RateLimitManager capacity data (concurrency, RPM, TPM) until that
  // telemetry exists. Do not reintroduce mocked values.
}
