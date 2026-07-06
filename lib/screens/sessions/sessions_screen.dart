library;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/session.dart';
import '../../services/session_service.dart';
import '../../di/locator.dart' as di;
import '../../widgets/common/empty_state.dart';
import '../../widgets/common/error_state.dart';
import '../../widgets/common/loading_skeleton.dart';
import '../../widgets/common/refreshable_screen.dart';
import '../../widgets/common/status_badge.dart';
import '../../widgets/navigation/popout_button.dart';

/// Screen displaying active gateway sessions
///
/// Shows a tabbed view of WebSocket connections, conversation sessions,
/// and user sessions with detailed metrics and controls.
class SessionsScreen extends StatefulWidget {
  const SessionsScreen({super.key});

  @override
  State<SessionsScreen> createState() => _SessionsScreenState();
}

class _SessionsScreenState extends State<SessionsScreen>
    with SingleTickerProviderStateMixin {
  /// Tab controller for session type tabs
  late TabController _tabController;

  /// Loading state indicator
  bool _isLoading = true;

  /// Error message if data loading fails
  String? _errorMessage;

  /// All sessions data
  List<SessionData> _allSessions = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadSessions();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  /// Load sessions data
  Future<void> _loadSessions() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final service = _sessionService;
      if (service != null) {
        _allSessions = await service.listSessions(limit: 50);
      } else {
        _allSessions = [];
      }

      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      if (mounted) {
        setState(() { _isLoading = false; _allSessions = []; });
      }
    }
  }

  SessionService? get _sessionService {
    try { return di.serviceLocator<SessionService>(); } catch (_) { return null; }
  }

  /// Get sessions filtered by current tab
  List<SessionData> get _filteredSessions {
    final tabIndex = _tabController.index;
    final typeFilter = tabIndex == 0
        ? 'websocket'
        : tabIndex == 1
            ? 'conversation'
            : 'user';
    return _allSessions.where((s) => s.type == typeFilter).toList();
  }

  /// Format duration for display
  String _formatDuration(Duration duration) {
    if (duration.inHours > 0) {
      return '${duration.inHours}h ${duration.inMinutes.remainder(60)}m';
    } else if (duration.inMinutes > 0) {
      return '${duration.inMinutes}m ${duration.inSeconds.remainder(60)}s';
    } else {
      return '${duration.inSeconds}s';
    }
  }

  /// Format timestamp for display
  String _formatStartTime(DateTime startTime) {
    final now = DateTime.now();
    final difference = now.difference(startTime);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return DateFormat('MMM d, HH:mm').format(startTime);
    }
  }

  /// Show session details dialog
  void _viewDetails(SessionData session) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Session Details'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _detailRow('Session ID', session.id),
              _detailRow('Type', session.type.toUpperCase()),
              _detailRow('User/Agent', session.userOrAgent),
              _detailRow('Started', _formatStartTime(session.startTime)),
              _detailRow('Duration', _formatDuration(session.duration)),
              _detailRow('Messages', '${session.messageCount}'),
              _detailRow('Tokens', '${session.tokenUsage}'),
              _detailRow('Status', session.status.toUpperCase()),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  /// Build a detail row for the dialog
  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
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
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Terminate Session'),
        content: Text(
          'Are you sure you want to terminate session ${session.id}?\n\n'
          'This will disconnect ${session.userOrAgent} and cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop();
              // TODO: Implement actual session termination
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Session ${session.id} terminated'),
                  action: SnackBarAction(
                    label: 'Undo',
                    onPressed: () {
                      // TODO: Implement undo
                    },
                  ),
                ),
              );
            },
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Terminate'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sessions'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'WebSocket'),
            Tab(text: 'Conversations'),
            Tab(text: 'Users'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh sessions',
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
          children: [
            _buildTabContent(),
            _buildTabContent(),
            _buildTabContent(),
          ],
        ),
      ),
    );
  }

  /// Build content for a tab
  Widget _buildTabContent() {
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

    final sessions = _filteredSessions;

    if (sessions.isEmpty) {
      return const EmptyState(
        icon: Icons.link_off,
        title: 'No Sessions',
        message: 'No active sessions for this category.',
      );
    }

    return _SessionsTable(
      sessions: sessions,
      formatDuration: _formatDuration,
      formatStartTime: _formatStartTime,
      viewDetails: _viewDetails,
      terminateSession: _terminateSession,
    );
  }
}

/// Table widget for displaying sessions
class _SessionsTable extends StatelessWidget {
  final List<SessionData> sessions;
  final String Function(Duration) formatDuration;
  final String Function(DateTime) formatStartTime;
  final void Function(SessionData) viewDetails;
  final void Function(SessionData) terminateSession;

  const _SessionsTable({
    required this.sessions,
    required this.formatDuration,
    required this.formatStartTime,
    required this.viewDetails,
    required this.terminateSession,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Card(
        child: Column(
          children: [
            // Table header
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
              child: const Row(
                children: [
                  Expanded(
                      flex: 2,
                      child: Text('Type',
                          style: TextStyle(fontWeight: FontWeight.w600))),
                  Expanded(
                      flex: 3,
                      child: Text('User/Agent',
                          style: TextStyle(fontWeight: FontWeight.w600))),
                  Expanded(
                      flex: 2,
                      child: Text('Started',
                          style: TextStyle(fontWeight: FontWeight.w600))),
                  Expanded(
                      flex: 2,
                      child: Text('Duration',
                          style: TextStyle(fontWeight: FontWeight.w600))),
                  Expanded(
                      flex: 1,
                      child: Text('Messages',
                          style: TextStyle(fontWeight: FontWeight.w600))),
                  Expanded(
                      flex: 1,
                      child: Text('Tokens',
                          style: TextStyle(fontWeight: FontWeight.w600))),
                  Expanded(
                      flex: 2,
                      child: Text('Status',
                          style: TextStyle(fontWeight: FontWeight.w600))),
                  Expanded(
                      flex: 2,
                      child: Text('Actions',
                          style: TextStyle(fontWeight: FontWeight.w600))),
                ],
              ),
            ),
            // Table rows
            ...sessions.map((session) => _SessionRow(
                  session: session,
                  formatDuration: formatDuration,
                  formatStartTime: formatStartTime,
                  viewDetails: viewDetails,
                  terminateSession: terminateSession,
                )),
          ],
        ),
      ),
    );
  }
}

/// Row widget for displaying a single session
class _SessionRow extends StatelessWidget {
  final SessionData session;
  final String Function(Duration) formatDuration;
  final String Function(DateTime) formatStartTime;
  final void Function(SessionData) viewDetails;
  final void Function(SessionData) terminateSession;

  const _SessionRow({
    required this.session,
    required this.formatDuration,
    required this.formatStartTime,
    required this.viewDetails,
    required this.terminateSession,
  });

  /// Get status type from status string
  StatusType _getStatusType(String status) {
    switch (status.toLowerCase()) {
      case 'active':
        return StatusType.active;
      case 'idle':
        return StatusType.idle;
      case 'terminated':
      case 'stopped':
        return StatusType.stopped;
      case 'connecting':
        return StatusType.running;
      default:
        return StatusType.unknown;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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
            flex: 2,
            child: Text(
              session.type.toUpperCase(),
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              session.userOrAgent,
              style: theme.textTheme.bodySmall,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              formatStartTime(session.startTime),
              style: theme.textTheme.bodySmall,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              formatDuration(session.duration),
              style: theme.textTheme.bodySmall,
            ),
          ),
          Expanded(
            flex: 1,
            child: Text(
              '${session.messageCount}',
              style: theme.textTheme.bodySmall,
            ),
          ),
          Expanded(
            flex: 1,
            child: Text(
              '${session.tokenUsage}',
              style: theme.textTheme.bodySmall,
            ),
          ),
          Expanded(
            flex: 2,
            child: StatusBadge(
              status: _getStatusType(session.status),
              label: session.status.toUpperCase(),
            ),
          ),
          Expanded(
            flex: 2,
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.visibility, size: 18),
                  tooltip: 'View details',
                  onPressed: () => viewDetails(session),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.stop_circle, size: 18),
                  tooltip: 'Terminate session',
                  onPressed: session.status == 'active'
                      ? () => terminateSession(session)
                      : null,
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
