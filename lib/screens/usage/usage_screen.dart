import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../widgets/usage/metric_card.dart';
import '../../widgets/navigation/popout_button.dart';

import 'package:pistisai/services/rate_limit_manager.dart';
import 'package:pistisai/database/drift_local_brain.dart';
import 'package:pistisai/di/locator.dart' as di;
import 'package:pistisai/l10n/app_localizations.dart';

enum TimeRange { today, week, month }

class UsageScreen extends StatefulWidget {
  const UsageScreen({super.key});

  @override
  State<UsageScreen> createState() => _UsageScreenState();
}

class _UsageScreenState extends State<UsageScreen> {
  TimeRange _selectedTimeRange = TimeRange.today;

  RateLimitManager? _rateLimitManager;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _rateLimitManager ??= _resolveRateLimitManager(context);
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
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.usageTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _onRefresh,
            tooltip: l10n.commonRefresh,
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
                  segments: [
                    ButtonSegment(
                      value: TimeRange.today,
                      label: Text(l10n.usageToday),
                      icon: const Icon(Icons.today),
                    ),
                    ButtonSegment(
                      value: TimeRange.week,
                      label: Text(l10n.usageWeek),
                      icon: const Icon(Icons.date_range),
                    ),
                    ButtonSegment(
                      value: TimeRange.month,
                      label: Text(l10n.usageMonth),
                      icon: const Icon(Icons.calendar_month),
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
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const SizedBox();
                  } else if (snapshot.hasError) {
                    return Text(l10n.commonErrorDetails('${snapshot.error}'));
                  } else {
                    final capacities = snapshot.data!;
                    final totalUsed =
                        capacities.fold(0, (sum, c) => sum + c.concurrentUsed);
                    final totalLimit =
                        capacities.fold(0, (sum, c) => sum + c.concurrentLimit);
                    final utilization =
                        totalLimit > 0 ? totalUsed / totalLimit : 0.0;

                    return MetricCard(
                      title: l10n.usageActiveConcurrency,
                      icon: Icons.sync,
                      value: '$totalUsed',
                      unit: l10n.usageOfLimit(totalLimit),
                      subtitle: l10n.usageConcurrencySubtitle,
                      trend: utilization > 0.8
                          ? MetricTrend.up
                          : MetricTrend.neutral,
                      progressValue: utilization,
                      progressLabel: l10n.usageConcurrencyUtilization,
                      child:
                          _buildConcurrencyBreakdown(theme, l10n, capacities),
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
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const SizedBox();
                  } else if (snapshot.hasError) {
                    return Text(l10n.commonErrorDetails('${snapshot.error}'));
                  } else {
                    final capacities = snapshot.data!;
                    final totalRpm =
                        capacities.fold(0, (sum, c) => sum + c.rpmUsed);
                    final totalRpmLimit =
                        capacities.fold(0, (sum, c) => sum + (c.rpmLimit ?? 0));
                    final rpmUtil =
                        totalRpmLimit > 0 ? totalRpm / totalRpmLimit : 0.0;

                    return MetricCard(
                      title: l10n.usageRequestRate,
                      icon: Icons.api,
                      value: '$totalRpm',
                      unit: l10n.usageRequestsPerMinuteUnit,
                      subtitle: l10n.usageRequestRateSubtitle,
                      trend: MetricTrend.neutral,
                      progressValue: rpmUtil,
                      progressLabel: l10n.usageRpmUtilization,
                      child: _buildRpmBreakdown(theme, l10n, capacities),
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
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const SizedBox();
                  } else if (snapshot.hasError) {
                    return Text(l10n.commonErrorDetails('${snapshot.error}'));
                  } else {
                    final capacities = snapshot.data!;
                    final totalTpm =
                        capacities.fold(0, (sum, c) => sum + c.tpmUsed);
                    final totalTpmLimit =
                        capacities.fold(0, (sum, c) => sum + (c.tpmLimit ?? 0));
                    final tpmUtil =
                        totalTpmLimit > 0 ? totalTpm / totalTpmLimit : 0.0;

                    return MetricCard(
                      title: l10n.usageTokenRate,
                      icon: Icons.token,
                      value: _formatTokenValue(totalTpm),
                      unit: l10n.usageTokensPerMinuteUnit,
                      subtitle: l10n.usageTokenRateSubtitle,
                      trend: MetricTrend.neutral,
                      progressValue: tpmUtil,
                      progressLabel: l10n.usageTpmUtilization,
                      child: _buildTpmBreakdown(theme, l10n, capacities),
                    );
                  }
                },
              ),

              const SizedBox(height: 24),

              // Chart placeholders
              _buildChartPlaceholder(l10n.usageChartTokenUsage),
              const SizedBox(height: 16),
              _buildChartPlaceholder(l10n.usageChartRequestVolume),
              const SizedBox(height: 16),
              _buildChartPlaceholder(l10n.usageChartResourceTrends),
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

  Widget _buildConcurrencyBreakdown(ThemeData theme, AppLocalizations l10n,
      List<ModelCapacityData> capacities) {
    if (capacities.isEmpty) {
      return _buildEmptyRow(theme, l10n.usageNoActiveModels);
    }
    final top = capacities.where((c) => c.concurrentLimit > 0).toList()
      ..sort((a, b) => b.concurrentUsed.compareTo(a.concurrentUsed));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Text(
          l10n.usagePerModelConcurrency,
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

  Widget _buildRpmBreakdown(ThemeData theme, AppLocalizations l10n,
      List<ModelCapacityData> capacities) {
    if (capacities.isEmpty) {
      return _buildEmptyRow(theme, l10n.usageNoRateData);
    }
    final withLimit = capacities.where((c) => c.rpmLimit != null).toList()
      ..sort((a, b) => b.rpmUsed.compareTo(a.rpmUsed));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Text(
          l10n.usageTopModelsByRpm,
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

  Widget _buildTpmBreakdown(ThemeData theme, AppLocalizations l10n,
      List<ModelCapacityData> capacities) {
    if (capacities.isEmpty) {
      return _buildEmptyRow(theme, l10n.usageNoTokenData);
    }
    final withLimit = capacities.where((c) => c.tpmLimit != null).toList()
      ..sort((a, b) => b.tpmUsed.compareTo(a.tpmUsed));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Text(
          l10n.usageTopModelsByTpm,
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
                      AppLocalizations.of(context).usageChartPlaceholder,
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
