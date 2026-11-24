import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../widgets/usage/metric_card.dart';

import 'package:pistisai/services/rate_limit_manager.dart';
import 'package:pistisai/database/drift_local_brain.dart';
import 'package:pistisai/di/locator.dart' as di;
import 'package:pistisai/l10n/app_localizations.dart';

class UsageScreen extends StatefulWidget {
  const UsageScreen({super.key});

  @override
  State<UsageScreen> createState() => _UsageScreenState();
}

class _UsageScreenState extends State<UsageScreen> {
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
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _onRefresh,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
                    // A finished empty stream (no RateLimitManager) has no
                    // data; treat it as "no models" instead of crashing.
                    final capacities =
                        snapshot.data ?? const <ModelCapacityData>[];
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
                      subtitle:
                          '${l10n.usageConcurrencySubtitle}\n${l10n.usageDefaultLimitsNote}',
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

              // Request rate, token rate and history are not tracked yet
              // (#858): rpmUsed/tpmUsed are never written, so show an
              // honest note instead of zero-valued cards and placeholder
              // charts.
              _buildNotAvailableCard(theme, l10n),
            ],
          ),
        ),
      ),
    );
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

  Widget _buildNotAvailableCard(ThemeData theme, AppLocalizations l10n) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              Icons.info_outline,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                l10n.usageNotAvailableYet,
                style: theme.textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // NOTE: Request rate, token rate and usage history have no data source
  // yet (rpmUsed/tpmUsed are never written). Only the concurrency counter,
  // which the embedded router updates, is shown. Do not reintroduce mocked
  // values or placeholder charts (#858).
}
