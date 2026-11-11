import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import '../../services/admin_center_service.dart';
import '../../models/admin_role_model.dart';
import '../../models/subscription_model.dart';
import '../../di/locator.dart' as di;
import 'dart:async';
import '../../config/theme.dart';

/// User Management Tab for the Admin Center
/// Provides search, filtering, and management of user accounts
class UserManagementTab extends StatefulWidget {
  const UserManagementTab({super.key});

  @override
  State<UserManagementTab> createState() => _UserManagementTabState();
}

class _UserManagementTabState extends State<UserManagementTab> {
  // Controllers
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounceTimer;

  // State
  List<Map<String, dynamic>> _users = [];
  bool _isLoading = false;

  /// Error built at display time so it follows the current locale.
  String Function(AppLocalizations)? _error;
  int _currentPage = 1;
  int _totalPages = 1;
  int _totalUsers = 0;
  final int _pageSize = 50;

  // Filters
  String? _selectedTier;
  String? _selectedStatus;
  String _sortBy = 'created_at';
  String _sortOrder = 'desc';

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  /// Load users with current filters
  Future<void> _loadUsers() async {
    final adminService = di.serviceLocator.get<AdminCenterService>();

    // Check permission
    if (!adminService.hasPermission(AdminPermission.viewUsers)) {
      setState(() {
        _error = (l10n) => l10n.adminUsersNoPermissionView;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final result = await adminService.getUsers(
        page: _currentPage,
        limit: _pageSize,
        search:
            _searchController.text.isNotEmpty ? _searchController.text : null,
        tier: _selectedTier,
        status: _selectedStatus,
        sortBy: _sortBy,
        sortOrder: _sortOrder,
      );

      setState(() {
        _users = List<Map<String, dynamic>>.from(result['users'] ?? []);
        _totalUsers = result['total'] ?? 0;
        _totalPages = result['totalPages'] ?? 1;
        _currentPage = result['page'] ?? 1;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = (l10n) => l10n.adminUsersLoadFailed('$e');
        _isLoading = false;
      });
    }
  }

  /// Handle search with debouncing
  void _onSearchChanged(String value) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      _currentPage = 1;
      _loadUsers();
    });
  }

  /// Handle filter change
  void _onFilterChanged() {
    _currentPage = 1;
    _loadUsers();
  }

  /// Handle page change
  void _onPageChanged(int page) {
    setState(() {
      _currentPage = page;
    });
    _loadUsers();
  }

  /// Show user detail dialog
  void _showUserDetail(Map<String, dynamic> user) {
    showDialog(
      context: context,
      builder: (context) => _UserDetailDialog(userId: user['id']),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppLocalizations.of(context).adminUsersTitle,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                AppLocalizations.of(context).adminUsersSubtitle,
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(color: AppTheme.colorsOf(context).textColorLight),
              ),
            ],
          ),
        ),

        // Search and filters
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            children: [
              // Search bar
              TextField(
                controller: _searchController,
                onChanged: _onSearchChanged,
                decoration: InputDecoration(
                  hintText: AppLocalizations.of(context).adminUsersSearchHint,
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            _onSearchChanged('');
                          },
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Filters row
              Row(
                children: [
                  // Tier filter
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _selectedTier,
                      decoration: InputDecoration(
                        labelText: AppLocalizations.of(context).adminUsersTierFilter,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      items: [
                        DropdownMenuItem(
                          value: null,
                          child: Text(AppLocalizations.of(context).adminUsersAllTiers),
                        ),
                        ...SubscriptionTier.values.map((tier) {
                          return DropdownMenuItem(
                            value: tier.name,
                            child: Text(tier.displayName),
                          );
                        }),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _selectedTier = value;
                        });
                        _onFilterChanged();
                      },
                    ),
                  ),
                  const SizedBox(width: 16),

                  // Status filter
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _selectedStatus,
                      decoration: InputDecoration(
                        labelText: AppLocalizations.of(context).adminUsersStatusFilter,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      items: [
                        DropdownMenuItem(
                          value: null,
                          child: Text(AppLocalizations.of(context).adminUsersAllStatuses),
                        ),
                        DropdownMenuItem(
                          value: 'active',
                          child: Text(AppLocalizations.of(context).adminStatusActive),
                        ),
                        DropdownMenuItem(
                          value: 'suspended',
                          child: Text(AppLocalizations.of(context).adminStatusSuspended),
                        ),
                        DropdownMenuItem(
                          value: 'deleted',
                          child: Text(AppLocalizations.of(context).adminStatusDeleted),
                        ),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _selectedStatus = value;
                        });
                        _onFilterChanged();
                      },
                    ),
                  ),
                  const SizedBox(width: 16),

                  // Sort options
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _sortBy,
                      decoration: InputDecoration(
                        labelText: AppLocalizations.of(context).adminUsersSortBy,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      items: [
                        DropdownMenuItem(
                          value: 'created_at',
                          child: Text(AppLocalizations.of(context).adminUsersSortRegistration),
                        ),
                        DropdownMenuItem(
                          value: 'last_login',
                          child: Text(AppLocalizations.of(context).adminUsersLastLogin),
                        ),
                        DropdownMenuItem(
                            value: 'email', child: Text(AppLocalizations.of(context).adminEmail)),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            _sortBy = value;
                          });
                          _onFilterChanged();
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Sort order toggle
                  IconButton(
                    icon: Icon(
                      _sortOrder == 'asc'
                          ? Icons.arrow_upward
                          : Icons.arrow_downward,
                    ),
                    onPressed: () {
                      setState(() {
                        _sortOrder = _sortOrder == 'asc' ? 'desc' : 'asc';
                      });
                      _onFilterChanged();
                    },
                    tooltip: _sortOrder == 'asc'
                        ? AppLocalizations.of(context).adminUsersAscending
                        : AppLocalizations.of(context).adminUsersDescending,
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // User table
        Expanded(child: _buildUserTable()),

        // Pagination
        if (_totalPages > 1) _buildPagination(),
      ],
    );
  }

  Widget _buildUserTable() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: AppTheme.colorsOf(context).danger),
            const SizedBox(height: 16),
            Text(_error!(AppLocalizations.of(context)),
                style: TextStyle(color: AppTheme.colorsOf(context).danger)),
            const SizedBox(height: 16),
            ElevatedButton(
                onPressed: _loadUsers, child: Text(AppLocalizations.of(context).commonRetry)),
          ],
        ),
      );
    }

    if (_users.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline, size: 48, color: AppTheme.colorsOf(context).textColorLight),
            SizedBox(height: 16),
            Text(AppLocalizations.of(context).adminUsersNone),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SingleChildScrollView(
        child: DataTable(
          columns: [
            DataColumn(label: Text(AppLocalizations.of(context).adminEmail)),
            DataColumn(label: Text(AppLocalizations.of(context).adminUsername)),
            DataColumn(label: Text(AppLocalizations.of(context).adminSubscription)),
            DataColumn(label: Text(AppLocalizations.of(context).commonStatus)),
            DataColumn(label: Text(AppLocalizations.of(context).adminRegistered)),
            DataColumn(label: Text(AppLocalizations.of(context).adminUsersLastLogin)),
            DataColumn(label: Text(AppLocalizations.of(context).commonActions)),
          ],
          rows: _users.map(_buildUserRow).toList(),
        ),
      ),
    );
  }

  DataRow _buildUserRow(Map<String, dynamic> user) {
    final tier = user['subscription_tier'] ?? 'free';
    final status = user['status'] ?? 'active';
    final createdAt = DateTime.tryParse(user['created_at'] ?? '');
    final lastLogin = DateTime.tryParse(user['last_login'] ?? '');

    return DataRow(
      cells: [
        DataCell(Text(user['email'] ?? '')),
        DataCell(Text(user['username'] ?? user['name'] ?? '')),
        DataCell(_buildTierChip(tier)),
        DataCell(_buildStatusChip(status)),
        DataCell(Text(createdAt != null
            ? _formatDate(createdAt)
            : AppLocalizations.of(context).adminNotAvailable)),
        DataCell(Text(lastLogin != null
            ? _formatDate(lastLogin)
            : AppLocalizations.of(context).commonNever)),
        DataCell(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.visibility, size: 20),
                onPressed: () => _showUserDetail(user),
                tooltip: AppLocalizations.of(context).adminViewDetails,
              ),
              IconButton(
                icon: const Icon(Icons.edit, size: 20),
                onPressed: () => _showEditDialog(user),
                tooltip: AppLocalizations.of(context).commonEdit,
              ),
              if (status == 'active')
                IconButton(
                  icon: Icon(Icons.block, size: 20, color: AppTheme.colorsOf(context).danger),
                  onPressed: () => _showSuspendDialog(user),
                  tooltip: AppLocalizations.of(context).adminSuspend,
                )
              else if (status == 'suspended')
                IconButton(
                  icon: Icon(
                    Icons.check_circle,
                    size: 20,
                    color: AppTheme.colorsOf(context).success,
                  ),
                  onPressed: () => _showReactivateDialog(user),
                  tooltip: AppLocalizations.of(context).adminReactivate,
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTierChip(String tier) {
    Color color;
    switch (tier.toLowerCase()) {
      case 'enterprise':
        color = AppTheme.colorsOf(context).accent;
        break;
      case 'premium':
        color = AppTheme.colorsOf(context).info;
        break;
      default:
        color = AppTheme.colorsOf(context).textColorLight;
    }

    return Chip(
      label: Text(
        tier.toUpperCase(),
        style: TextStyle(fontSize: 12, color: AppTheme.colorsOf(context).textColor),
      ),
      backgroundColor: color,
      padding: EdgeInsets.zero,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }

  Widget _buildStatusChip(String status) {
    Color color;
    switch (status.toLowerCase()) {
      case 'active':
        color = AppTheme.colorsOf(context).success;
        break;
      case 'suspended':
        color = AppTheme.colorsOf(context).danger;
        break;
      case 'deleted':
        color = AppTheme.colorsOf(context).textColorLight;
        break;
      default:
        color = AppTheme.colorsOf(context).warning;
    }

    return Chip(
      label: Text(
        status.toUpperCase(),
        style: TextStyle(fontSize: 12, color: AppTheme.colorsOf(context).textColor),
      ),
      backgroundColor: color,
      padding: EdgeInsets.zero,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }

  Widget _buildPagination() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.colorsOf(context).textColorLight,
        border: Border(top: BorderSide(color: AppTheme.colorsOf(context).textColorLight)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            AppLocalizations.of(context).adminUsersShowing(
              (_currentPage - 1) * _pageSize + 1,
              _currentPage * _pageSize > _totalUsers
                  ? _totalUsers
                  : _currentPage * _pageSize,
              _totalUsers,
            ),
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: _currentPage > 1
                    ? () => _onPageChanged(_currentPage - 1)
                    : null,
              ),
              Text(AppLocalizations.of(context).adminPageOf(_currentPage, _totalPages)),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: _currentPage < _totalPages
                    ? () => _onPageChanged(_currentPage + 1)
                    : null,
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  void _showEditDialog(Map<String, dynamic> user) {
    showDialog(
      context: context,
      builder: (context) => _EditUserDialog(
        user: user,
        onSaved: () {
          Navigator.of(context).pop();
          _loadUsers(); // Refresh the list
        },
      ),
    );
  }

  void _showSuspendDialog(Map<String, dynamic> user) {
    showDialog(
      context: context,
      builder: (context) => _SuspendUserDialog(
        user: user,
        onSuspended: () {
          Navigator.of(context).pop();
          _loadUsers(); // Refresh the list
        },
      ),
    );
  }

  void _showReactivateDialog(Map<String, dynamic> user) {
    showDialog(
      context: context,
      builder: (context) => _ReactivateUserDialog(
        user: user,
        onReactivated: () {
          Navigator.of(context).pop();
          _loadUsers(); // Refresh the list
        },
      ),
    );
  }
}

/// User Detail Dialog - displays comprehensive user information
class _UserDetailDialog extends StatefulWidget {
  final String userId;

  const _UserDetailDialog({required this.userId});

  @override
  State<_UserDetailDialog> createState() => _UserDetailDialogState();
}

class _UserDetailDialogState extends State<_UserDetailDialog> {
  bool _isLoading = true;

  /// Error built at display time so it follows the current locale.
  String Function(AppLocalizations)? _error;
  Map<String, dynamic>? _userDetails;

  @override
  void initState() {
    super.initState();
    _loadUserDetails();
  }

  Future<void> _loadUserDetails() async {
    final adminService = di.serviceLocator.get<AdminCenterService>();

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final details = await adminService.getUserDetails(widget.userId);
      setState(() {
        _userDetails = details;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = (l10n) => l10n.adminUserDetailsLoadFailed('$e');
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: 800,
        height: 600,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  AppLocalizations.of(context).adminUserDetails,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const Divider(),
            const SizedBox(height: 16),

            // Content
            Expanded(child: _buildContent()),

            // Actions
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(AppLocalizations.of(context).commonClose),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: AppTheme.colorsOf(context).danger),
            const SizedBox(height: 16),
            Text(_error!(AppLocalizations.of(context)),
                style: TextStyle(color: AppTheme.colorsOf(context).danger)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadUserDetails,
              child: Text(AppLocalizations.of(context).commonRetry),
            ),
          ],
        ),
      );
    }

    if (_userDetails == null) {
      return Center(child: Text(AppLocalizations.of(context).adminNoUserDetails));
    }

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Profile Information
          _buildSection(AppLocalizations.of(context).adminProfileInfo, [
            _buildInfoRow(AppLocalizations.of(context).adminUserId, _userDetails!['id'] ?? 'N/A'),
            _buildInfoRow(AppLocalizations.of(context).adminEmail, _userDetails!['email'] ?? 'N/A'),
            _buildInfoRow(
              AppLocalizations.of(context).adminUsername,
              _userDetails!['username'] ?? _userDetails!['name'] ?? 'N/A',
            ),
            _buildInfoRow(AppLocalizations.of(context).commonStatus, _userDetails!['status'] ?? 'N/A'),
            _buildInfoRow(
              AppLocalizations.of(context).adminRegistered,
              _formatDateTime(_userDetails!['created_at']),
            ),
            _buildInfoRow(
              AppLocalizations.of(context).adminUsersLastLogin,
              _formatDateTime(_userDetails!['last_login']),
            ),
          ]),

          const SizedBox(height: 24),

          // Subscription Information
          if (_userDetails!['subscription'] != null)
            _buildSection(AppLocalizations.of(context).adminSubscriptionInfo, [
              _buildInfoRow(
                AppLocalizations.of(context).adminTier,
                _userDetails!['subscription']['tier'] ?? 'N/A',
              ),
              _buildInfoRow(
                AppLocalizations.of(context).commonStatus,
                _userDetails!['subscription']['status'] ?? 'N/A',
              ),
              _buildInfoRow(
                AppLocalizations.of(context).adminPeriodStart,
                _formatDateTime(
                  _userDetails!['subscription']['current_period_start'],
                ),
              ),
              _buildInfoRow(
                AppLocalizations.of(context).adminPeriodEnd,
                _formatDateTime(
                  _userDetails!['subscription']['current_period_end'],
                ),
              ),
              if (_userDetails!['subscription']['cancel_at_period_end'] == true)
                _buildInfoRow(
                  AppLocalizations.of(context).adminCancellation,
                  AppLocalizations.of(context).adminCancelAtPeriodEnd,
                  isWarning: true,
                ),
            ]),

          const SizedBox(height: 24),

          // Payment History
          if (_userDetails!['payment_history'] != null &&
              (_userDetails!['payment_history'] as List).isNotEmpty)
            _buildSection(AppLocalizations.of(context).adminRecentPayments, [
              _buildPaymentHistoryTable(_userDetails!['payment_history']),
            ]),

          const SizedBox(height: 24),

          // Session Information
          if (_userDetails!['sessions'] != null &&
              (_userDetails!['sessions'] as List).isNotEmpty)
            _buildSection(AppLocalizations.of(context).adminActiveSessions, [
              _buildSessionsTable(_userDetails!['sessions']),
            ]),

          const SizedBox(height: 24),

          // Activity Timeline
          if (_userDetails!['activity'] != null &&
              (_userDetails!['activity'] as List).isNotEmpty)
            _buildSection(AppLocalizations.of(context).adminRecentActivity, [
              _buildActivityTimeline(_userDetails!['activity']),
            ]),
        ],
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        ...children,
      ],
    );
  }

  Widget _buildInfoRow(String label, String value, {bool isWarning = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 180,
            child: Text(
              AppLocalizations.of(context).commonFieldLabel(label),
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: AppTheme.colorsOf(context).textColorLight,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: isWarning ? AppTheme.colorsOf(context).warning : null,
                fontWeight: isWarning ? FontWeight.bold : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentHistoryTable(List<dynamic> payments) {
    return DataTable(
      columns: [
        DataColumn(label: Text(AppLocalizations.of(context).adminDate)),
        DataColumn(label: Text(AppLocalizations.of(context).adminAmount)),
        DataColumn(label: Text(AppLocalizations.of(context).commonStatus)),
        DataColumn(label: Text(AppLocalizations.of(context).adminMethod)),
      ],
      rows: payments.take(5).map((payment) {
        return DataRow(
          cells: [
            DataCell(Text(_formatDateTime(payment['created_at']))),
            DataCell(
              Text('\$${payment['amount']?.toStringAsFixed(2) ?? '0.00'}'),
            ),
            DataCell(Text(payment['status'] ?? 'N/A')),
            DataCell(Text(payment['payment_method_type'] ?? 'N/A')),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildSessionsTable(List<dynamic> sessions) {
    return DataTable(
      columns: [
        DataColumn(label: Text(AppLocalizations.of(context).adminIpAddress)),
        DataColumn(label: Text(AppLocalizations.of(context).adminUserAgent)),
        DataColumn(label: Text(AppLocalizations.of(context).adminLastActive)),
      ],
      rows: sessions.take(5).map((session) {
        return DataRow(
          cells: [
            DataCell(Text(session['ip_address'] ?? 'N/A')),
            DataCell(
              SizedBox(
                width: 200,
                child: Text(
                  session['user_agent'] ?? 'N/A',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            DataCell(Text(_formatDateTime(session['last_active']))),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildActivityTimeline(List<dynamic> activities) {
    return Column(
      children: activities.take(10).map((activity) {
        return ListTile(
          leading: const Icon(Icons.circle, size: 12),
          title: Text(activity['action'] ?? AppLocalizations.of(context).adminUnknownAction),
          subtitle: Text(_formatDateTime(activity['created_at'])),
          dense: true,
        );
      }).toList(),
    );
  }

  String _formatDateTime(dynamic dateTime) {
    if (dateTime == null) return 'N/A';
    try {
      final dt = DateTime.parse(dateTime.toString());
      return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return AppLocalizations.of(context).adminInvalidDate;
    }
  }
}

/// Edit User Dialog - allows changing subscription tier
class _EditUserDialog extends StatefulWidget {
  final Map<String, dynamic> user;
  final VoidCallback onSaved;

  const _EditUserDialog({required this.user, required this.onSaved});

  @override
  State<_EditUserDialog> createState() => _EditUserDialogState();
}

class _EditUserDialogState extends State<_EditUserDialog> {
  late String _selectedTier;
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _selectedTier = widget.user['subscription_tier'] ?? 'free';
  }

  Future<void> _saveChanges() async {
    final l10n = AppLocalizations.of(context);
    final adminService = di.serviceLocator.get<AdminCenterService>();

    // Check permission
    if (!adminService.hasPermission(AdminPermission.editUsers)) {
      setState(() {
        _error = l10n.adminNoPermissionEdit;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      await adminService.updateUserSubscription(
        widget.user['id'],
        _selectedTier,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.adminSubscriptionUpdated),
          ),
        );
        widget.onSaved();
      }
    } catch (e) {
      setState(() {
        _error = l10n.adminUpdateFailed('$e');
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(AppLocalizations.of(context).adminEditSubscriptionTitle),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(AppLocalizations.of(context).adminUserLabel('${widget.user['email']}')),
            const SizedBox(height: 24),
            DropdownButtonFormField<String>(
              initialValue: _selectedTier,
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context).adminUsersTierFilter,
                border: OutlineInputBorder(),
              ),
              items: SubscriptionTier.values.map((tier) {
                return DropdownMenuItem(
                  value: tier.name,
                  child: Text(tier.displayName),
                );
              }).toList(),
              onChanged: _isLoading
                  ? null
                  : (value) {
                      if (value != null) {
                        setState(() {
                          _selectedTier = value;
                        });
                      }
                    },
            ),
            if (_error != null) ...[
              const SizedBox(height: 16),
              Text(_error!, style: TextStyle(color: AppTheme.colorsOf(context).danger)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: Text(AppLocalizations.of(context).commonCancel),
        ),
        FilledButton(
          onPressed: _isLoading ? null : _saveChanges,
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(AppLocalizations.of(context).commonSave),
        ),
      ],
    );
  }
}

/// Suspend User Dialog - allows suspending a user account with reason
class _SuspendUserDialog extends StatefulWidget {
  final Map<String, dynamic> user;
  final VoidCallback onSuspended;

  const _SuspendUserDialog({required this.user, required this.onSuspended});

  @override
  State<_SuspendUserDialog> createState() => _SuspendUserDialogState();
}

class _SuspendUserDialogState extends State<_SuspendUserDialog> {
  final TextEditingController _reasonController = TextEditingController();
  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _suspendUser() async {
    final l10n = AppLocalizations.of(context);
    if (_reasonController.text.trim().isEmpty) {
      setState(() {
        _error = l10n.adminSuspendReasonMissing;
      });
      return;
    }

    final adminService = di.serviceLocator.get<AdminCenterService>();

    // Check permission
    if (!adminService.hasPermission(AdminPermission.suspendUsers)) {
      setState(() {
        _error = l10n.adminNoPermissionSuspend;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      await adminService.suspendUser(
        widget.user['id'],
        _reasonController.text.trim(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.adminSuspended)),
        );
        widget.onSuspended();
      }
    } catch (e) {
      setState(() {
        _error = l10n.adminSuspendFailed('$e');
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(AppLocalizations.of(context).adminSuspendTitle),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(AppLocalizations.of(context).adminUserLabel('${widget.user['email']}')),
            const SizedBox(height: 16),
            Text(
              AppLocalizations.of(context).adminSuspendWarning,
              style: TextStyle(color: AppTheme.colorsOf(context).warning),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _reasonController,
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context).adminSuspendReason,
                hintText: AppLocalizations.of(context).adminSuspendReasonHint,
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
              enabled: !_isLoading,
            ),
            if (_error != null) ...[
              const SizedBox(height: 16),
              Text(_error!, style: TextStyle(color: AppTheme.colorsOf(context).danger)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: Text(AppLocalizations.of(context).commonCancel),
        ),
        FilledButton(
          onPressed: _isLoading ? null : _suspendUser,
          style: FilledButton.styleFrom(backgroundColor: AppTheme.colorsOf(context).danger),
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(AppLocalizations.of(context).adminSuspend),
        ),
      ],
    );
  }
}

/// Reactivate User Dialog - allows reactivating a suspended user account
class _ReactivateUserDialog extends StatefulWidget {
  final Map<String, dynamic> user;
  final VoidCallback onReactivated;

  const _ReactivateUserDialog({
    required this.user,
    required this.onReactivated,
  });

  @override
  State<_ReactivateUserDialog> createState() => _ReactivateUserDialogState();
}

class _ReactivateUserDialogState extends State<_ReactivateUserDialog> {
  bool _isLoading = false;
  String? _error;

  Future<void> _reactivateUser() async {
    final l10n = AppLocalizations.of(context);
    final adminService = di.serviceLocator.get<AdminCenterService>();

    // Check permission
    if (!adminService.hasPermission(AdminPermission.suspendUsers)) {
      setState(() {
        _error = l10n.adminNoPermissionReactivate;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      await adminService.reactivateUser(widget.user['id']);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.adminReactivated)),
        );
        widget.onReactivated();
      }
    } catch (e) {
      setState(() {
        _error = l10n.adminReactivateFailed('$e');
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(AppLocalizations.of(context).adminReactivateTitle),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(AppLocalizations.of(context).adminUserLabel('${widget.user['email']}')),
            const SizedBox(height: 16),
            Text(
              AppLocalizations.of(context).adminReactivateInfo,
            ),
            if (_error != null) ...[
              const SizedBox(height: 16),
              Text(_error!, style: TextStyle(color: AppTheme.colorsOf(context).danger)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: Text(AppLocalizations.of(context).commonCancel),
        ),
        FilledButton(
          onPressed: _isLoading ? null : _reactivateUser,
          style: FilledButton.styleFrom(backgroundColor: AppTheme.colorsOf(context).success),
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(AppLocalizations.of(context).adminReactivate),
        ),
      ],
    );
  }
}
