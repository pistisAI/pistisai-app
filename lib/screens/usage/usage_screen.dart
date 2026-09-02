import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../widgets/usage/metric_card.dart';
import '../../widgets/navigation/popout_button.dart';

import 'package:pistisai/services/rate_limit_manager.dart';
import 'package:pistisai/services/usage_instrumentation_service.dart';
import 'package:pistisai/database/drift_local_brain.dart';
import 'package:pistisai/di/locator.dart' as di;

enum TimeRange { today, week, month }

class UsageScreen extends StatefulWidget {
  const UsageScreen({super.key});

  @override
  State<UsageScreen> createState() => _UsageScreenState();
}

class _UsageScreenState extends State<UsageScreen> {
  TimeRange _selectedTimeRange = TimeRange.today;
  UsageChartData? _chartData;

  RateLimitManager? _rateLimitManager;
  UsageInstrumentationService? _usageInstrumentation;

  @override
  void initState() {
    super.initState();
    _loadChartData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _rateLimitManager ??= _resolveRateLimitManager(context);
    _usageInstrumentation ??= _resolveUsageInstrumentation();
  }

  static UsageInstrumentationService? _resolveUsageInstrumentation() {
    try {
      return di.serviceLocator.get<UsageInstrumentationService>();
    } catch (_) {
      return null;
    }
  }

  DateTime get _rangeStart {
    final now = DateTime.now();
    switch (_selectedTimeRange) {
      case TimeRange.today:
        return DateTime(now.year, now.month, now.day);
      case TimeRange.week:
        return now.subtract(const Duration(days: 7));
      case TimeRange.month:
        return now.subtract(const Duration(days: 30));
    }
  }

  Future<void> _loadChartData() async {
    final instrumentation = _usageInstrumentation ?? _resolveUsageInstrumentation();
    if (instrumentation == null) {
      if (mounted) setState(() => _chartData = null);
      return;
    }

    final data = await instrumentation.buildChartData(_rangeStart);
    if (mounted) {
      setState(() => _chartData = data);
    }
  }

  static RateLimitManager? _resolveRateLimitManager(BuildContext context) {
    try {
      return context.read<RateLimitManager>();
    } catch (_) {
      // Not provided above this widget; fall back to the service locator.
    }
    try {
      return di.serviceLocator.get<RateLimitManager>();
    } catch (_) {
      return null;
    }
  }

  Future<void> _onRefresh() async {
    setState(() {});
    await _loadChartData();
  }

  void _onTimeRangeChanged(Set<TimeRange> newSelection) {
    if (newSelection.isNotEmpty) {
      setState(() {
        _selectedTimeRange = newSelection.first;
      });
      _loadChartData();
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
                          stream: _rateLimitManager?.watchCapacities() ??
                              const Stream.empty(),
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
                          stream: _rateLimitManager?.watchCapacities() ??
                              const Stream.empty(),
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
                          stream: _rateLimitManager?.watchCapacities() ??
                              const Stream.empty(),
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

                        _buildTokenUsageChart(),
                        const SizedBox(height: 16),
                        _buildRequestVolumeChart(),
                        const SizedBox(height: 16),
                        _buildResourceTrendsCard(),
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

  Widget _buildTokenUsageChart() {
    final theme = Theme.of(context);
    final data = _chartData;

    return Card(
      child: Container(
        height: 220,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Token Usage Over Time',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: data == null || data.labels.isEmpty
                  ? _buildEmptyChart(theme, 'No token usage recorded yet')
                  : LineChart(
                      LineChartData(
                        gridData: const FlGridData(show: true),
                        titlesData: const FlTitlesData(show: false),
                        borderData: FlBorderData(show: false),
                        lineBarsData: [
                          LineChartBarData(
                            spots: [
                              for (var i = 0; i < data.labels.length; i++)
                                FlSpot(
                                  i.toDouble(),
                                  data.tokenTotals[i].toDouble(),
                                ),
                            ],
                            isCurved: true,
                            color: theme.colorScheme.primary,
                            barWidth: 3,
                            dotData: const FlDotData(show: false),
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

  Widget _buildRequestVolumeChart() {
    final theme = Theme.of(context);
    final data = _chartData;

    return Card(
      child: Container(
        height: 220,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Request Volume',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: data == null || data.labels.isEmpty
                  ? _buildEmptyChart(theme, 'No requests recorded yet')
                  : BarChart(
                      BarChartData(
                        gridData: const FlGridData(show: false),
                        titlesData: const FlTitlesData(show: false),
                        borderData: FlBorderData(show: false),
                        barGroups: [
                          for (var i = 0; i < data.labels.length; i++)
                            BarChartGroupData(
                              x: i,
                              barRods: [
                                BarChartRodData(
                                  toY: data.requestCounts[i].toDouble(),
                                  color: theme.colorScheme.secondary,
                                  width: 12,
                                ),
                              ],
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

  Widget _buildResourceTrendsCard() {
    final theme = Theme.of(context);
    final data = _chartData;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Resource Trends',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            if (data == null)
              _buildEmptyChart(theme, 'Usage instrumentation unavailable')
            else ...[
              _buildMetricRow(
                'Total requests',
                '${data.totalRequests}',
                Icons.api,
                theme.colorScheme.primary,
                theme,
              ),
              _buildMetricRow(
                'Total tokens',
                _formatTokenValue(data.totalTokens),
                Icons.token,
                theme.colorScheme.secondary,
                theme,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyChart(ThemeData theme, String message) {
    return Center(
      child: Text(
        message,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
        ),
      ),
    );
  }

  // NOTE: Per-user request success/latency/CPU metrics have no backend
  // endpoint or client data source yet. The cards above use real
  // RateLimitManager capacity data (concurrency, RPM, TPM) until that
  // telemetry exists. Do not reintroduce mocked values.
}
