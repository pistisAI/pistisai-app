import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import '../../di/locator.dart' as di;
import '../../services/admin_center_service.dart';
import '../../models/admin_role_model.dart';
import '../../config/theme.dart';

/// Admin Management Tab for managing administrator accounts and roles.
/// Only accessible to Super Admin users.
///
/// Features:
/// - List all administrators with their roles
/// - Add new administrators by searching for users
/// - Assign roles (Support Admin or Finance Admin)
/// - Revoke admin roles
/// - View admin activity history
class AdminManagementTab extends StatefulWidget {
  const AdminManagementTab({super.key});

  @override
  State<AdminManagementTab> createState() => _AdminManagementTabState();
}

class _AdminManagementTabState extends State<AdminManagementTab> {
  List<Map<String, dynamic>> _admins = [];
  bool _isLoading = false;

  /// Error built at display time so it follows the current locale.
  String Function(AppLocalizations)? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadAdmins();
  }

  /// Load all administrators
  Future<void> _loadAdmins() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final adminService = di.serviceLocator.get<AdminCenterService>();
      final response = await adminService.getAdmins();

      setState(() {
        _admins = List<Map<String, dynamic>>.from(response['admins'] ?? []);
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = (l10n) => l10n.adminsLoadFailed('$e');
        _isLoading = false;
      });
    }
  }

  /// Show add admin dialog
  Future<void> _showAddAdminDialog() async {
    await showDialog(
      context: context,
      builder: (context) => _AddAdminDialog(onAdminAdded: _loadAdmins),
    );
  }

  /// Show revoke role confirmation dialog
  Future<void> _showRevokeRoleDialog(
    Map<String, dynamic> admin,
    Map<String, dynamic> role,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context).adminsRevokeTitle),
        content: Text(
          AppLocalizations.of(context).adminsRevokeConfirm(
              _formatRole(role['role']), '${admin['email']}'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(AppLocalizations.of(context).commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(backgroundColor: AppTheme.colorsOf(context).danger),
            child: Text(AppLocalizations.of(context).adminsRevoke),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await _revokeRole(admin['userId'], role['role']);
    }
  }

  /// Revoke admin role
  Future<void> _revokeRole(String userId, String role) async {
    final l10n = AppLocalizations.of(context);
    try {
      final adminService = di.serviceLocator.get<AdminCenterService>();
      await adminService.revokeAdminRole(userId, role);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.adminsRevoked)),
        );
        await _loadAdmins();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.adminsRevokeFailed('$e'))));
      }
    }
  }

  /// Format role name for display
  String _formatRole(String role) {
    switch (role) {
      case 'super_admin':
        return AppLocalizations.of(context).adminsRoleSuper;
      case 'support_admin':
        return AppLocalizations.of(context).adminsRoleSupport;
      case 'finance_admin':
        return AppLocalizations.of(context).adminsRoleFinance;
      default:
        return role;
    }
  }

  /// Get role badge color
  Color _getRoleColor(BuildContext context, String role) {
    switch (role) {
      case 'super_admin':
        return AppTheme.colorsOf(context).accent;
      case 'support_admin':
        return AppTheme.colorsOf(context).info;
      case 'finance_admin':
        return AppTheme.colorsOf(context).success;
      default:
        return AppTheme.colorsOf(context).textColorLight;
    }
  }

  @override
  Widget build(BuildContext context) {
    final adminService = context.watch<AdminCenterService>();

    // Check if user is Super Admin
    if (!adminService.isSuperAdmin) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lock_outline, size: 64, color: AppTheme.colorsOf(context).danger),
            const SizedBox(height: 16),
            Text(
              AppLocalizations.of(context).adminsSuperRequired,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(AppLocalizations.of(context).adminsSuperRequiredBody),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppLocalizations.of(context).adminsTitle,
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      AppLocalizations.of(context).adminsSubtitle,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppTheme.colorsOf(context).textColorLight.withValues(alpha: 0.7),
                          ),
                    ),
                  ],
                ),
              ),
              FilledButton.icon(
                onPressed: _showAddAdminDialog,
                icon: const Icon(Icons.person_add),
                label: Text(AppLocalizations.of(context).adminsAdd),
              ),
            ],
          ),
        ),

        const Divider(height: 1),

        // Error message
        if (_errorMessage != null)
          Container(
            padding: const EdgeInsets.all(16.0),
            color: AppTheme.colorsOf(context).danger.withValues(alpha: 0.1),
            child: Row(
              children: [
                Icon(Icons.error_outline, color: AppTheme.colorsOf(context).danger),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _errorMessage!(AppLocalizations.of(context)),
                    style: TextStyle(color: AppTheme.colorsOf(context).danger),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close, color: AppTheme.colorsOf(context).danger),
                  onPressed: () => setState(() => _errorMessage = null),
                ),
              ],
            ),
          ),

        // Loading indicator
        if (_isLoading)
          const Expanded(child: Center(child: CircularProgressIndicator()))
        else if (_admins.isEmpty)
          Expanded(child: Center(child: Text(AppLocalizations.of(context).adminsNone)))
        else
          // Admin list
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16.0),
              itemCount: _admins.length,
              itemBuilder: (context, index) {
                final admin = _admins[index];
                return _buildAdminCard(admin);
              },
            ),
          ),
      ],
    );
  }

  /// Build admin card
  Widget _buildAdminCard(Map<String, dynamic> admin) {
    final roles = List<Map<String, dynamic>>.from(admin['roles'] ?? []);
    final activeRoles = roles.where((r) => r['isActive'] == true).toList();
    final activitySummary = admin['activitySummary'] as Map<String, dynamic>?;

    return Card(
      margin: const EdgeInsets.only(bottom: 12.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Admin info
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppTheme.colorsOf(context).info.withValues(alpha: 0.15),
                  child: Text(
                    admin['email']?.substring(0, 1).toUpperCase() ?? '?',
                    style: TextStyle(
                      color: AppTheme.colorsOf(context).info,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        admin['email'] ?? AppLocalizations.of(context).adminsUnknown,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      if (admin['username'] != null)
                        Text(
                          admin['username'],
                          style: TextStyle(
                            color: AppTheme.colorsOf(context).textColorLight.withValues(alpha: 0.7),
                            fontSize: 14,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Active roles
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: activeRoles.map((role) {
                return Chip(
                  label: Text(_formatRole(role['role'])),
                  backgroundColor: _getRoleColor(context,
                    role['role'],
                  ).withValues(alpha: 0.1),
                  labelStyle: TextStyle(
                    color: _getRoleColor(context, role['role']),
                    fontWeight: FontWeight.bold,
                  ),
                  deleteIcon: role['role'] != 'super_admin'
                      ? const Icon(Icons.close, size: 18)
                      : null,
                  onDeleted: role['role'] != 'super_admin'
                      ? () => _showRevokeRoleDialog(admin, role)
                      : null,
                );
              }).toList(),
            ),

            const SizedBox(height: 12),

            // Activity summary
            if (activitySummary != null)
              Container(
                padding: const EdgeInsets.all(12.0),
                decoration: BoxDecoration(
                  color: AppTheme.colorsOf(context).textColorLight.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildActivityStat(
                        AppLocalizations.of(context).adminsTotalActions,
                        activitySummary['totalActions']?.toString() ?? '0',
                      ),
                    ),
                    Expanded(
                      child: _buildActivityStat(
                        AppLocalizations.of(context).adminsRecent30d,
                        activitySummary['recentActions']?.toString() ?? '0',
                      ),
                    ),
                    Expanded(
                      child: _buildActivityStat(
                        AppLocalizations.of(context).adminsLastAction,
                        activitySummary['lastActionAt'] != null
                            ? _formatDate(activitySummary['lastActionAt'])
                            : AppLocalizations.of(context).commonNever,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Build activity stat
  Widget _buildActivityStat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 12, color: AppTheme.colorsOf(context).textColorLight.withValues(alpha: 0.7)),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  /// Format date for display
  String _formatDate(dynamic date) {
    if (date == null) return AppLocalizations.of(context).commonNever;
    try {
      final dateTime =
          date is DateTime ? date : DateTime.parse(date.toString());
      final now = DateTime.now();
      final difference = now.difference(dateTime);

      if (difference.inDays == 0) {
        return AppLocalizations.of(context).adminsToday;
      } else if (difference.inDays == 1) {
        return AppLocalizations.of(context).adminYesterday;
      } else if (difference.inDays < 7) {
        return AppLocalizations.of(context).timeDaysAgo(difference.inDays);
      } else if (difference.inDays < 30) {
        return AppLocalizations.of(context).adminsWeeksAgo((difference.inDays / 7).floor());
      } else {
        return AppLocalizations.of(context).adminsMonthsAgo((difference.inDays / 30).floor());
      }
    } catch (e) {
      return AppLocalizations.of(context).adminsUnknown;
    }
  }
}

/// Dialog for adding a new admin
class _AddAdminDialog extends StatefulWidget {
  final VoidCallback onAdminAdded;

  const _AddAdminDialog({required this.onAdminAdded});

  @override
  State<_AddAdminDialog> createState() => _AddAdminDialogState();
}

class _AddAdminDialogState extends State<_AddAdminDialog> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  AdminRole _selectedRole = AdminRole.supportAdmin;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  /// Add admin
  Future<void> _addAdmin() async {
    final l10n = AppLocalizations.of(context);
    if (_formKey.currentState == null || !_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final adminService = di.serviceLocator.get<AdminCenterService>();
      await adminService.assignAdminRole(
        _emailController.text.trim(),
        _selectedRole,
      );

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.adminsAssigned)),
        );
        widget.onAdminAdded();
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(AppLocalizations.of(context).adminsAddTitle),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Email field
            TextFormField(
              controller: _emailController,
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context).adminsEmailAddress,
                hintText: 'user@example.com',
                prefixIcon: Icon(Icons.email),
              ),
              keyboardType: TextInputType.emailAddress,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return AppLocalizations.of(context).adminsEmailRequired;
                }
                if (!value.contains('@')) {
                  return AppLocalizations.of(context).adminsEmailInvalid;
                }
                return null;
              },
            ),

            const SizedBox(height: 16),

            // Role selection
            Text(AppLocalizations.of(context).adminsSelectRole, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            DropdownButtonFormField<AdminRole>(
              initialValue: _selectedRole,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.admin_panel_settings),
              ),
              items: [
                DropdownMenuItem(
                  value: AdminRole.supportAdmin,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(AppLocalizations.of(context).adminsRoleSupport),
                      Text(
                        AppLocalizations.of(context).adminsSupportDescription,
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.colorsOf(context).textColorLight.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ),
                DropdownMenuItem(
                  value: AdminRole.financeAdmin,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(AppLocalizations.of(context).adminsRoleFinance),
                      Text(
                        AppLocalizations.of(context).adminsFinanceDescription,
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.colorsOf(context).textColorLight.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() => _selectedRole = value);
                }
              },
            ),

            // Error message
            if (_errorMessage != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12.0),
                decoration: BoxDecoration(
                  color: AppTheme.colorsOf(context).danger.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.error_outline,
                      color: AppTheme.colorsOf(context).danger,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: TextStyle(color: AppTheme.colorsOf(context).danger, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
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
          onPressed: _isLoading ? null : _addAdmin,
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(AppLocalizations.of(context).adminsAdd),
        ),
      ],
    );
  }
}
