import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_localizations.dart';
import '../../services/approval_gate_service.dart';

/// Host that surfaces pending critical-action approvals as a modal dialog.
///
/// Place near the app shell so agent/workflow pauses are visible before
/// [ApprovalGateService.runCritical] continues.
class ApprovalGateHost extends StatelessWidget {
  const ApprovalGateHost({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Consumer<ApprovalGateService>(
      builder: (context, gate, _) {
        final pending = gate.pendingRequests;
        return Stack(
          children: [
            child,
            if (pending.isNotEmpty)
              ModalBarrier(
                dismissible: false,
                color: Colors.black54,
              ),
            if (pending.isNotEmpty)
              Center(
                child: ApprovalRequestPanel(
                  action: pending.first,
                  onApprove: () => gate.resolve(
                    pending.first.id,
                    ApprovalVerdict.approved,
                  ),
                  onDeny: () => gate.resolve(
                    pending.first.id,
                    ApprovalVerdict.denied,
                    note: 'denied by user',
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Clear summary of a pending critical action with Approve / Deny controls.
class ApprovalRequestPanel extends StatelessWidget {
  const ApprovalRequestPanel({
    required this.action,
    required this.onApprove,
    required this.onDeny,
    super.key,
  });

  final CriticalAction action;
  final VoidCallback onApprove;
  final VoidCallback onDeny;

  String _categoryLabel(AppLocalizations l10n) {
    switch (action.category) {
      case CriticalActionCategory.dataExport:
        return l10n.approvalCategoryDataExport;
      case CriticalActionCategory.integrationCall:
        return l10n.approvalCategoryIntegrationCall;
      case CriticalActionCategory.custom:
        return l10n.approvalCategoryCustom;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final detailEntries = action.details.entries.toList();

    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(12),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.approvalTitle,
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                l10n.approvalSubtitle,
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              Text(
                action.title,
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              Text(
                _categoryLabel(l10n),
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.secondary,
                ),
              ),
              const SizedBox(height: 12),
              Text(action.summary, style: theme.textTheme.bodyLarge),
              if (action.workflowId != null) ...[
                const SizedBox(height: 8),
                Text(
                  l10n.approvalWorkflow(action.workflowId!),
                  style: theme.textTheme.bodySmall,
                ),
              ],
              if (detailEntries.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(l10n.approvalDetailsHeading,
                    style: theme.textTheme.labelLarge),
                const SizedBox(height: 4),
                ...detailEntries.map(
                  (e) => Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Text(
                      '${e.key}: ${e.value}',
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: onDeny,
                    child: Text(l10n.approvalDeny),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: onApprove,
                    child: Text(l10n.approvalApprove),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
