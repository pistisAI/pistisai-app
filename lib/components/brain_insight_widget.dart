import 'dart:async';

import 'package:flutter/material.dart';

import '../config/theme.dart';
import '../database/local_brain.dart';
import '../di/locator.dart';
import '../l10n/app_localizations.dart';
import '../services/agent_action_audit_service.dart';

/// Shows the local agent activity journal (#860).
///
/// Reads the entries [AgentActionAuditService] records for agent tool use and
/// other audited actions. It shows real rows, an empty state, or a read error;
/// it never shows placeholder data.
class BrainInsightWidget extends StatefulWidget {
  const BrainInsightWidget({
    super.key,
    this.audit,
    this.refreshInterval = const Duration(seconds: 5),
    this.limit = 200,
  });

  /// Journal to read. Defaults to the registered [AgentActionAuditService].
  final AgentActionAuditService? audit;
  final Duration refreshInterval;
  final int limit;

  @override
  State<BrainInsightWidget> createState() => _BrainInsightWidgetState();
}

class _BrainInsightWidgetState extends State<BrainInsightWidget> {
  AgentActionAuditService? _audit;
  List<AgentActionAuditEntry>? _entries;
  bool _failed = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _audit = widget.audit ??
        (serviceLocator.isRegistered<AgentActionAuditService>()
            ? serviceLocator.get<AgentActionAuditService>()
            : null);
    if (_audit != null) {
      unawaited(_load());
      _timer = Timer.periodic(widget.refreshInterval, (_) => _load());
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final audit = _audit;
    if (audit == null) return;
    try {
      final entries = await audit.list(limit: widget.limit);
      if (!mounted) return;
      setState(() {
        _entries = entries;
        _failed = false;
      });
    } catch (e) {
      debugPrint('[BrainInsightWidget] Failed to read audit journal: $e');
      if (!mounted) return;
      setState(() => _failed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colors = AppTheme.colorsOf(context);

    return Card(
      elevation: 4,
      margin: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Icon(Icons.psychology, color: colors.accent),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.brainInsightsJournalTitle,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        l10n.brainInsightsJournalSubtitle,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.textColorLight,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(),
          Expanded(child: _buildBody(context, l10n)),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context, AppLocalizations l10n) {
    if (_audit == null) {
      return Center(child: Text(l10n.brainInsightsUnavailable));
    }
    if (_failed && _entries == null) {
      return Center(
        child: Text(
          l10n.brainInsightsLoadError,
          style: TextStyle(color: AppTheme.colorsOf(context).danger),
        ),
      );
    }
    final entries = _entries;
    if (entries == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (entries.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(l10n.brainInsightsEmpty, textAlign: TextAlign.center),
        ),
      );
    }
    return ListView.separated(
      itemCount: entries.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) {
        // [AgentActionAuditService.list] is newest-first.
        final entry = entries[index];
        return ListTile(
          dense: true,
          leading: _outcomeIcon(context, entry.outcome),
          title: Text(entry.action),
          subtitle: Text(
            [
              entry.timestamp.toLocal().toIso8601String(),
              entry.outcome,
              entry.authorizationStatus,
              if (entry.dataTouched.isNotEmpty) entry.dataTouched,
            ].join(' | '),
            style: const TextStyle(fontSize: 10),
          ),
        );
      },
    );
  }

  Widget _outcomeIcon(BuildContext context, String outcome) {
    final colors = AppTheme.colorsOf(context);
    return switch (outcome) {
      AgentAuditOutcome.failure =>
        Icon(Icons.error, color: colors.danger, size: 20),
      AgentAuditOutcome.blocked =>
        Icon(Icons.block, color: colors.warning, size: 20),
      _ => Icon(Icons.check_circle, color: colors.success, size: 20),
    };
  }
}
