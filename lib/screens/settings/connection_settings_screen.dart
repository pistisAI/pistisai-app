import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../di/locator.dart' as di;
import '../../l10n/app_localizations.dart';
import '../../widgets/navigation/breadcrumb_bar.dart';
import '../../services/onboarding/setup_wizard_service.dart';
import '../../services/settings_preference_service.dart';

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
    final setupWizardService = context.read<SetupWizardService>();
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

                // Remote hub access (#861): opt-in, token-protected, honest.
                const _RemoteHubAccessCard(),
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

                      if (confirmed != true || !mounted) return;
                      try {
                        // Clears the deferred flag, the stored completion
                        // record and the step state, then re-checks that the
                        // wizard is really due before navigating to it.
                        final wizardDue = await setupWizardService.restart();
                        if (!context.mounted) return;
                        if (!wizardDue) {
                          throw StateError('setup wizard is still marked done');
                        }
                        context.go('/setup');
                      } catch (e) {
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(l10n.connectionClearFailed('$e')),
                            backgroundColor: AppTheme.colorsOf(context).danger,
                          ),
                        );
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

/// Opt-in switch for LAN/Tailscale access to the embedded desktop hub.
///
/// The router binds at service setup, so the setting is applied on the next
/// start. The token is generated then and shown here for the phone.
class _RemoteHubAccessCard extends StatefulWidget {
  const _RemoteHubAccessCard();

  @override
  State<_RemoteHubAccessCard> createState() => _RemoteHubAccessCardState();
}

class _RemoteHubAccessCardState extends State<_RemoteHubAccessCard> {
  late final SettingsPreferenceService _settings;
  bool _enabled = false;
  String? _token;

  @override
  void initState() {
    super.initState();
    _settings = di.serviceLocator.isRegistered<SettingsPreferenceService>()
        ? di.serviceLocator.get<SettingsPreferenceService>()
        : SettingsPreferenceService();
    _load();
  }

  Future<void> _load() async {
    final enabled = await _settings.isRemoteHubAccessEnabled();
    final token = await _settings.getRemoteHubToken();
    if (!mounted) return;
    setState(
      () {
        _enabled = enabled;
        _token = token;
      },
    );
  }

  Future<void> _toggle(bool value) async {
    await _settings.setRemoteHubAccessEnabled(value);
    await _load();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content:
              Text(AppLocalizations.of(context).connectionRemoteHubRestart)),
    );
  }

  Future<void> _copyToken(String token) async {
    await Clipboard.setData(ClipboardData(text: token));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content:
              Text(AppLocalizations.of(context).connectionRemoteHubCopied)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SwitchListTile(
              key: const Key('remoteHubAccessToggle'),
              value: _enabled,
              title: Text(l10n.connectionRemoteHubTitle),
              subtitle: Text(l10n.connectionRemoteHubSubtitle),
              onChanged: _toggle,
            ),
            if (_enabled) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _token == null || _token!.isEmpty
                    ? Text(l10n.connectionRemoteHubTokenPending)
                    : Row(
                        children: [
                          Expanded(
                            child: SelectableText(
                              _token!,
                              key: const Key('remoteHubAccessToken'),
                            ),
                          ),
                          IconButton(
                            key: const Key('remoteHubAccessCopy'),
                            icon: const Icon(Icons.copy),
                            tooltip: l10n.connectionRemoteHubCopy,
                            onPressed: () => _copyToken(_token!),
                          ),
                        ],
                      ),
              ),
              const SizedBox(height: 12),
            ],
          ],
        ),
      ),
    );
  }
}
