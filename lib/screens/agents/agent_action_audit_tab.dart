import 'dart:convert';

import 'package:file_selector/file_selector.dart' as file_selector;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:pistisai/config/theme.dart';
import 'package:pistisai/config/theme_extensions.dart';
import 'package:pistisai/database/drift_local_brain.dart';
import 'package:pistisai/di/locator.dart' as di;
import 'package:pistisai/l10n/app_localizations.dart';
import 'package:pistisai/services/agent_action_audit_service.dart';
import 'package:pistisai/utils/file_download_helper.dart';
import 'package:pistisai/widgets/common/empty_state.dart';
import 'package:pistisai/widgets/common/error_state.dart';
import 'package:pistisai/widgets/common/loading_skeleton.dart';

/// Client-visible local agent-action audit journal (#643).
class AgentActionAuditTab extends StatefulWidget {
  const AgentActionAuditTab({super.key});

  @override
  State<AgentActionAuditTab> createState() => _AgentActionAuditTabState();
}

class _AgentActionAuditTabState extends State<AgentActionAuditTab> {
  bool _isLoading = true;
  String? _errorMessage;
  List<AgentActionAuditEntry> _entries = const [];

  AgentActionAuditService? get _audit {
    try {
      if (!di.serviceLocator.isRegistered<AgentActionAuditService>()) {
        return null;
      }
      return di.serviceLocator<AgentActionAuditService>();
    } catch (_) {
      return null;
    }
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final service = _audit;
      if (service == null) {
        _entries = const [];
      } else {
        _entries = await service.list(limit: 500);
      }
      if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = '$e';
          _entries = const [];
        });
      }
    }
  }

  Future<void> _export({required bool asCsv}) async {
    final l10n = AppLocalizations.of(context);
    final service = _audit;
    if (service == null) {
      _snack(l10n.agentsAuditUnavailable);
      return;
    }

    try {
      final content =
          asCsv ? await service.exportCsv() : await service.exportJson();
      final filename = service.generateExportFilename(
        extension: asCsv ? 'csv' : 'json',
      );
      final mime = asCsv ? 'text/csv' : 'application/json';

      final bytes = utf8.encode(content);
      if (kIsWeb) {
        downloadFile(bytes, filename, mime);
      } else {
        final saveLocation = await file_selector.getSaveLocation(
          acceptedTypeGroups: [
            file_selector.XTypeGroup(
              label: asCsv ? 'CSV' : 'JSON',
              extensions: [asCsv ? 'csv' : 'json'],
            ),
          ],
          suggestedName: filename,
        );
        if (saveLocation == null) return;
        final xfile = file_selector.XFile.fromData(
          bytes,
          mimeType: mime,
          name: filename,
        );
        await xfile.saveTo(saveLocation.path);
      }

      if (!mounted) return;
      _snack(l10n.agentsAuditExported(filename));
    } catch (e) {
      if (!mounted) return;
      _snack(l10n.agentsAuditExportFailed('$e'));
    }
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    if (_isLoading) {
      return const LoadingSkeleton(itemCount: 4, height: 72);
    }
    if (_errorMessage != null) {
      return ErrorState(message: _errorMessage!, onRetry: _load);
    }
    if (_audit == null) {
      return EmptyState(
        icon: Icons.policy_outlined,
        title: l10n.agentsAuditTitle,
        message: l10n.agentsAuditUnavailable,
      );
    }
    if (_entries.isEmpty) {
      return EmptyState(
        icon: Icons.policy_outlined,
        title: l10n.agentsAuditEmptyTitle,
        message: l10n.agentsAuditEmptyMessage,
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  l10n.agentsAuditShowing(_entries.length),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
              TextButton.icon(
                onPressed: () => _export(asCsv: false),
                icon: const Icon(Icons.download_outlined),
                label: Text(l10n.agentsAuditExportJson),
              ),
              const SizedBox(width: 8),
              TextButton.icon(
                onPressed: () => _export(asCsv: true),
                icon: const Icon(Icons.table_view_outlined),
                label: Text(l10n.agentsAuditExportCsv),
              ),
              IconButton(
                onPressed: _load,
                tooltip: l10n.commonRefresh,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            itemCount: _entries.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              return _AuditEntryCard(entry: _entries[index], l10n: l10n);
            },
          ),
        ),
      ],
    );
  }
}

class _AuditEntryCard extends StatelessWidget {
  const _AuditEntryCard({required this.entry, required this.l10n});

  final AgentActionAuditEntry entry;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = AppTheme.colorsOf(context);

    return Material(
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    entry.action,
                    style: theme.textTheme.titleSmall,
                  ),
                ),
                _StatusChip(
                  label: entry.authorizationStatus,
                  color: _authColor(entry.authorizationStatus, colors),
                ),
                const SizedBox(width: 6),
                _StatusChip(
                  label: entry.outcome,
                  color: _outcomeColor(entry.outcome, colors),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              entry.timestamp.toLocal().toIso8601String(),
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 4),
            Text(
              '${l10n.agentsAuditDataTouched}: ${entry.dataTouched}',
              style: theme.textTheme.bodyMedium,
            ),
            if (entry.authorizedBy != null && entry.authorizedBy!.isNotEmpty)
              Text(
                '${l10n.agentsAuditAuthorizedBy}: ${entry.authorizedBy}',
                style: theme.textTheme.bodySmall,
              ),
            if (entry.agentId != null && entry.agentId!.isNotEmpty)
              Text(
                '${l10n.agentsAuditAgent}: ${entry.agentId}',
                style: theme.textTheme.bodySmall,
              ),
          ],
        ),
      ),
    );
  }

  Color _authColor(String status, AppColorsTheme colors) {
    switch (status) {
      case AgentAuditAuthorization.authorized:
      case AgentAuditAuthorization.autoAllowed:
        return colors.success;
      case AgentAuditAuthorization.denied:
        return colors.danger;
      case AgentAuditAuthorization.pending:
        return colors.warning;
      default:
        return colors.textColorLight;
    }
  }

  Color _outcomeColor(String outcome, AppColorsTheme colors) {
    switch (outcome) {
      case AgentAuditOutcome.success:
        return colors.success;
      case AgentAuditOutcome.failure:
      case AgentAuditOutcome.blocked:
        return colors.danger;
      default:
        return colors.textColorLight;
    }
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color),
      ),
    );
  }
}
