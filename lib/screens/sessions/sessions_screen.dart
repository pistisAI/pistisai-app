library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/session.dart';
import '../../services/session_service.dart';
import '../../di/locator.dart' as di;
import '../../l10n/app_localizations.dart';
import '../../widgets/common/empty_state.dart';
import '../../widgets/common/error_state.dart';
import '../../widgets/common/loading_skeleton.dart';
import '../../widgets/common/refreshable_screen.dart';
import '../../widgets/navigation/popout_button.dart';

/// Hermes sessions from `hermes sessions list`, in two tabs: agent
/// sessions and scheduled (cron) sessions. Only columns the CLI provides are
/// shown: title, last message preview, last active and id.
class SessionsScreen extends StatefulWidget {
  const SessionsScreen({super.key});

  @override
  State<SessionsScreen> createState() => _SessionsScreenState();
}

class _SessionsScreenState extends State<SessionsScreen>
    with SingleTickerProviderStateMixin {
  /// Session types shown by each tab, in tab order.
  static const _tabTypes = ['agent', 'cron'];

  late TabController _tabController;
  bool _isLoading = true;
  String? _errorMessage;
  List<SessionData> _allSessions = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabTypes.length, vsync: this);
    _loadSessions();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadSessions() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final service = _sessionService;
    if (service == null) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _allSessions = [];
          _errorMessage =
              AppLocalizations.of(context).sessionsServiceUnavailable;
        });
      }
      return;
    }

    try {
      final sessions = await service.listSessions(limit: 50);
      if (mounted) {
        setState(() {
          _allSessions = sessions;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _allSessions = [];
          _errorMessage = '$e';
        });
      }
    }
  }

  SessionService? get _sessionService {
    try {
      return di.serviceLocator<SessionService>();
    } catch (_) {
      return null;
    }
  }

  void _viewDetails(SessionData session) {
    final l10n = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.sessionsDetailsTitle),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _detailRow(l10n.sessionsId, session.id),
              _detailRow(l10n.commonType, session.type.toUpperCase()),
              _detailRow(l10n.sessionsUserOrAgent, session.userOrAgent),
              if (session.preview != null)
                _detailRow(l10n.sessionsPreview, session.preview!),
              if (session.lastActive != null)
                _detailRow(l10n.sessionsLastActive, session.lastActive!),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.commonClose),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              AppLocalizations.of(context).commonFieldLabel(label),
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface.withValues(
                      alpha: 0.6,
                    ),
              ),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  /// Terminate session after confirmation
  void _terminateSession(SessionData session) {
    final l10n = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.sessionsTerminateTitle),
        content: Text(
          l10n.sessionsTerminateConfirm(session.id, session.userOrAgent),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.of(context).pop();

              final service = _sessionService;
              final messenger = ScaffoldMessenger.of(context);
              final errorColor = Theme.of(context).colorScheme.error;
              if (service == null) {
                messenger.showSnackBar(
                  SnackBar(
                    content: Text(l10n.sessionsServiceUnavailable),
                    backgroundColor: errorColor,
                  ),
                );
                return;
              }

              final ok = await service.terminate(session.id);

              if (ok) {
                unawaited(_loadSessions());
                messenger.showSnackBar(
                  SnackBar(
                    content: Text(l10n.sessionsTerminated(session.id)),
                  ),
                );
              } else {
                messenger.showSnackBar(
                  SnackBar(
                    content: Text(l10n.sessionsTerminateFailed(session.id)),
                    backgroundColor: errorColor,
                  ),
                );
              }
            },
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: Text(l10n.sessionsTerminate),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.sessionsTitle),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: l10n.sessionsTabAgents),
            Tab(text: l10n.sessionsTabScheduled),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: l10n.sessionsRefresh,
            onPressed: _isLoading ? null : _loadSessions,
          ),
          const PopOutButton(
            sectionName: 'sessions',
            branchIndex: 4,
          ),
        ],
      ),
      body: RefreshableScreen(
        onRefresh: _loadSessions,
        errorMessage: _errorMessage,
        child: TabBarView(
          controller: _tabController,
          children: [for (final type in _tabTypes) _buildTabContent(type)],
        ),
      ),
    );
  }

  Widget _buildTabContent(String type) {
    if (_isLoading) {
      return const LoadingSkeleton(
        itemCount: 5,
        height: 72,
      );
    }

    if (_errorMessage != null) {
      return ErrorState(
        message: _errorMessage!,
        onRetry: _loadSessions,
      );
    }

    final sessions = _allSessions.where((s) => s.type == type).toList();

    if (sessions.isEmpty) {
      final l10n = AppLocalizations.of(context);
      return EmptyState(
        icon: Icons.link_off,
        title: l10n.sessionsEmptyTitle,
        message: l10n.sessionsEmptyMessage,
      );
    }

    return _SessionsTable(
      sessions: sessions,
      viewDetails: _viewDetails,
      terminateSession: _terminateSession,
    );
  }
}

class _SessionsTable extends StatelessWidget {
  final List<SessionData> sessions;
  final void Function(SessionData) viewDetails;
  final void Function(SessionData) terminateSession;

  const _SessionsTable({
    required this.sessions,
    required this.viewDetails,
    required this.terminateSession,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    const headerStyle = TextStyle(fontWeight: FontWeight.w600);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Card(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                      flex: 3,
                      child:
                          Text(l10n.sessionsUserOrAgent, style: headerStyle)),
                  Expanded(
                      flex: 4,
                      child: Text(l10n.sessionsPreview, style: headerStyle)),
                  Expanded(
                      flex: 2,
                      child: Text(l10n.sessionsLastActive, style: headerStyle)),
                  Expanded(
                      flex: 2,
                      child: Text(l10n.commonActions, style: headerStyle)),
                ],
              ),
            ),
            ...sessions.map((session) => _SessionRow(
                  session: session,
                  viewDetails: viewDetails,
                  terminateSession: terminateSession,
                )),
          ],
        ),
      ),
    );
  }
}

class _SessionRow extends StatelessWidget {
  final SessionData session;
  final void Function(SessionData) viewDetails;
  final void Function(SessionData) terminateSession;

  const _SessionRow({
    required this.session,
    required this.viewDetails,
    required this.terminateSession,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 12,
      ),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.outlineVariant,
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              session.userOrAgent,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            flex: 4,
            child: Text(
              session.preview ?? '—',
              style: theme.textTheme.bodySmall,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              session.lastActive ?? '—',
              style: theme.textTheme.bodySmall,
            ),
          ),
          Expanded(
            flex: 2,
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.visibility, size: 18),
                  tooltip: l10n.sessionsViewDetails,
                  onPressed: () => viewDetails(session),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.stop_circle, size: 18),
                  tooltip: l10n.sessionsTerminateTooltip,
                  onPressed: () => terminateSession(session),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
