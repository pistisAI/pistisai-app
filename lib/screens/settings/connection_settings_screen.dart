import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../l10n/app_localizations.dart';
import '../../widgets/navigation/breadcrumb_bar.dart';
import '../../services/setup_status_service.dart';
import '../../services/auth_service.dart';

/// Connection Settings Screen - Network and tunnel configuration
class ConnectionSettingsScreen extends StatefulWidget {
  const ConnectionSettingsScreen({super.key});

  @override
  State<ConnectionSettingsScreen> createState() =>
      _ConnectionSettingsScreenState();
}

class _ConnectionSettingsScreenState extends State<ConnectionSettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final spacing = AppTheme.spacingOf(context);
    final setupStatusService = context.watch<SetupStatusService>();
    final authService = context.watch<AuthService>();
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.connectionSettingsTitle),
        elevation: 0,
        leading: BackButton(
          onPressed: () {
            context.go('/config');
          },
        ),
      ),
      body: Column(
        children: [
          const AutoBreadcrumbBar(),
          Expanded(
            child: ListView(
              padding: EdgeInsets.all(spacing.l),
              children: [
                Text(l10n.connectionHeading,
                    style: theme.textTheme.headlineMedium),
                const SizedBox(height: 16),
                Text(l10n.connectionDescription),
                const SizedBox(height: 32),

                // Daemon Settings
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.settings_ethernet),
                    title: Text(l10n.connectionDaemonSettings),
                    subtitle: Text(l10n.connectionDaemonSubtitle),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.go('/settings/daemon'),
                  ),
                ),
                const SizedBox(height: 8),

                // Device Mesh
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.devices),
                    title: Text(l10n.meshTitle),
                    subtitle: Text(l10n.connectionDeviceMeshSubtitle),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.go('/settings/device-mesh'),
                  ),
                ),
                const SizedBox(height: 8),

                // Connection Status
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.link),
                    title: Text(l10n.connectionStatusTitle),
                    subtitle: Text(l10n.connectionStatusSubtitle),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.go('/settings/connection-status'),
                  ),
                ),
                const SizedBox(height: 8),

                // Re-run Setup Wizard
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.restart_alt),
                    title: Text(l10n.connectionRerunWizard),
                    subtitle: Text(l10n.connectionRerunWizardSubtitle),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () async {
                      // Confirm before clearing setup
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: Text(l10n.connectionRerunWizard),
                          content: Text(l10n.connectionRerunWizardBody),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(false),
                              child: Text(l10n.commonCancel),
                            ),
                            FilledButton(
                              onPressed: () => Navigator.of(context).pop(true),
                              style: FilledButton.styleFrom(
                                backgroundColor:
                                    AppTheme.colorsOf(context).warning,
                              ),
                              child: Text(l10n.connectionClearAndRerun),
                            ),
                          ],
                        ),
                      );

                      if (confirmed == true && mounted) {
                        try {
                          // Get user ID before async operations
                          final userId = authService.currentUser?.id ?? 'local';

                          // Clear all setup data
                          await setupStatusService.clearAllSetupData();

                          // Also reset gateway token
                          await setupStatusService.resetSetupStatus(userId);

                          if (mounted) {
                            // Navigate to setup wizard
                            if (!context.mounted) return;
                            context.go('/setup');
                          }
                        } catch (e) {
                          if (mounted) {
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(l10n.connectionClearFailed('$e')),
                                backgroundColor:
                                    AppTheme.colorsOf(context).danger,
                              ),
                            );
                          }
                        }
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
