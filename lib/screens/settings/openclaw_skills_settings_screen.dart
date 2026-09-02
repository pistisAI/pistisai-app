import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../config/theme.dart';
import '../../config/theme_extensions.dart';
import '../../widgets/navigation/breadcrumb_bar.dart';
import '../../services/openclaw_skill_install_service.dart';
import '../../di/locator.dart' as di;

/// Settings screen for OpenClaw skill installation and management.
///
/// Detects if the OpenClaw personality skill is installed, provides a
/// one-click install button, shows installation status, and offers
/// manual installation instructions as a fallback.
class OpenClawSkillsSettingsScreen extends StatefulWidget {
  const OpenClawSkillsSettingsScreen({super.key});

  @override
  State<OpenClawSkillsSettingsScreen> createState() =>
      _OpenClawSkillsSettingsScreenState();
}

class _OpenClawSkillsSettingsScreenState
    extends State<OpenClawSkillsSettingsScreen> {
  OpenClawSkillInstallService? _installService;
  bool _isChecking = true;
  bool _showManualInstructions = false;

  @override
  void initState() {
    super.initState();
    _initService();
  }

  Future<void> _initService() async {
    try {
      _installService = di.serviceLocator<OpenClawSkillInstallService>();
      _installService!.addListener(_onServiceChanged);
      await _installService!.checkStatus();
    } catch (_) {
      // Service not registered yet — create a local instance
      _installService = OpenClawSkillInstallService();
      _installService!.addListener(_onServiceChanged);
      await _installService!.checkStatus();
    }

    if (mounted) {
      setState(() => _isChecking = false);
    }
  }

  void _onServiceChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _installService?.removeListener(_onServiceChanged);
    super.dispose();
  }

  Future<void> _handleInstall() async {
    if (_installService == null) return;

    final success = await _installService!.install();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? 'OpenClaw skill installed successfully!'
                : 'Installation failed: ${_installService!.errorMessage}',
          ),
          backgroundColor:
              success ? AppTheme.successColor : AppTheme.dangerColor,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final spacing = AppTheme.spacingOf(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('OpenClaw Skills'),
        elevation: 0,
        leading: BackButton(
          onPressed: () => context.go('/'),
        ),
      ),
      body: Column(
        children: [
          const AutoBreadcrumbBar(),
          Expanded(
            child: ListView(
              padding: EdgeInsets.all(spacing.l),
              children: [
                Text(
                  'OpenClaw Skills',
                  style: theme.textTheme.headlineMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  'Manage the OpenClaw personality skill that powers '
                  'avatar personality, evolution tracking, and '
                  'conversation memory.',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: AppTheme.textColorLight,
                  ),
                ),
                const SizedBox(height: 32),

                // Status card
                _buildStatusCard(theme, spacing),
                const SizedBox(height: 16),

                // Action card
                _buildActionCard(theme, spacing),
                const SizedBox(height: 16),

                // Manual instructions toggle
                _buildManualInstructionsToggle(theme, spacing),
                if (_showManualInstructions) ...[
                  const SizedBox(height: 12),
                  _buildManualInstructions(theme, spacing),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCard(ThemeData theme, AppSpacingTheme spacing) {
    if (_isChecking) {
      return Card(
        child: Padding(
          padding: EdgeInsets.all(spacing.m),
          child: Row(
            children: [
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 16),
              Text('Checking installation status...'),
            ],
          ),
        ),
      );
    }

    final service = _installService;
    if (service == null) {
      return Card(
        child: Padding(
          padding: EdgeInsets.all(spacing.m),
          child: Row(
            children: [
              const Icon(Icons.error_outline, color: AppTheme.dangerColor),
              const SizedBox(width: 16),
              Expanded(
                child: Text('Unable to check installation status.'),
              ),
            ],
          ),
        ),
      );
    }

    IconData icon;
    Color iconColor;
    String title;
    String subtitle;

    switch (service.status) {
      case OpenClawSkillStatus.installed:
        icon = Icons.check_circle;
        iconColor = AppTheme.successColor;
        title = 'Skill Installed';
        subtitle =
            'Version: ${service.installedVersion ?? 'unknown'}';
        break;
      case OpenClawSkillStatus.notInstalled:
        icon = Icons.info_outline;
        iconColor = AppTheme.warningColor;
        title = 'Not Installed';
        subtitle = 'The OpenClaw personality skill is not yet installed.';
        break;
      case OpenClawSkillStatus.installing:
        icon = Icons.sync;
        iconColor = AppTheme.infoColor;
        title = 'Installing...';
        subtitle = 'Copying skill files to the target directory.';
        break;
      case OpenClawSkillStatus.error:
        icon = Icons.error;
        iconColor = AppTheme.dangerColor;
        title = 'Installation Error';
        subtitle = service.errorMessage ?? 'An unknown error occurred.';
        break;
    }

    return Card(
      child: Padding(
        padding: EdgeInsets.all(spacing.m),
        child: Row(
          children: [
            Icon(icon, color: iconColor, size: 32),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppTheme.textColorLight,
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

  Widget _buildActionCard(ThemeData theme, AppSpacingTheme spacing) {
    final service = _installService;
    if (service == null) return const SizedBox.shrink();

    final isInstalled = service.isInstalled;
    final isInstalling = service.status == OpenClawSkillStatus.installing;

    return Card(
      child: Padding(
        padding: EdgeInsets.all(spacing.m),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isInstalled ? Icons.cloud_done : Icons.cloud_download,
                  size: 20,
                  color: isInstalled
                      ? AppTheme.successColor
                      : AppTheme.primaryColor,
                ),
                const SizedBox(width: 8),
                Text(
                  isInstalled ? 'Installation Status' : 'One-Click Install',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            if (isInstalled) ...[
              // Already installed — show reinstall option
              Text(
                'The OpenClaw personality skill is installed and ready. '
                'Click below to reinstall if needed.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppTheme.textColorLight,
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: isInstalling ? null : _handleInstall,
                  icon: isInstalling
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh),
                  label: Text(isInstalling ? 'Reinstalling...' : 'Reinstall'),
                ),
              ),
            ] else ...[
              // Not installed — show install button
              Text(
                'Click the button below to install the OpenClaw personality '
                'skill. This will copy the skill package to '
                '~/.openclaw/skills/pistisai/.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppTheme.textColorLight,
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: isInstalling ? null : _handleInstall,
                  icon: isInstalling
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.download),
                  label: Text(isInstalling ? 'Installing...' : 'Install Skill'),
                ),
              ),
            ],

            if (service.status == OpenClawSkillStatus.error &&
                service.errorMessage != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.dangerColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppTheme.borderRadiusM),
                  border: Border.all(
                    color: AppTheme.dangerColor.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.warning_amber,
                        color: AppTheme.dangerColor, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        service.errorMessage!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppTheme.dangerColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildManualInstructionsToggle(
      ThemeData theme, AppSpacingTheme spacing) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.help_outline),
        title: const Text('Manual Installation'),
        subtitle: const Text(
          'If the one-click install does not work, follow these steps.',
        ),
        trailing: Icon(
          _showManualInstructions
              ? Icons.expand_less
              : Icons.expand_more,
        ),
        onTap: () {
          setState(() => _showManualInstructions = !_showManualInstructions);
        },
      ),
    );
  }

  Widget _buildManualInstructions(ThemeData theme, AppSpacingTheme spacing) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(spacing.m),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Manual Installation Steps',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            _buildStep(
              number: '1',
              text: 'Navigate to the Pistisai app repository:',
              code: 'cd pistisai-app',
            ),
            const SizedBox(height: 8),
            _buildStep(
              number: '2',
              text: 'Create the target directory:',
              code: 'mkdir -p ~/.openclaw/skills/pistisai',
            ),
            const SizedBox(height: 8),
            _buildStep(
              number: '3',
              text: 'Copy the skill package:',
              code:
                  'cp -r services/openclaw-skills/pistisai/* ~/.openclaw/skills/pistisai/',
            ),
            const SizedBox(height: 8),
            _buildStep(
              number: '4',
              text: 'Install dependencies:',
              code: 'cd ~/.openclaw/skills/pistisai && npm install',
            ),
            const SizedBox(height: 8),
            _buildStep(
              number: '5',
              text: 'Verify installation:',
              code: 'ls -la ~/.openclaw/skills/pistisai/',
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.infoColor.withValues(alpha: 0.1),
                borderRadius:
                    BorderRadius.circular(AppTheme.borderRadiusM),
                border: Border.all(
                  color: AppTheme.infoColor.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.lightbulb_outline,
                      color: AppTheme.infoColor, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'After installation, restart the OpenClaw gateway '
                      'for the skill to be detected.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppTheme.infoColor,
                      ),
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

  Widget _buildStep({
    required String number,
    required String text,
    required String code,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withValues(alpha: 0.2),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              number,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryColor,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(text, style: const TextStyle(fontSize: 13)),
              const SizedBox(height: 4),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppTheme.backgroundMain,
                  borderRadius:
                      BorderRadius.circular(AppTheme.borderRadiusS),
                ),
                child: Text(
                  code,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    color: AppTheme.primaryColor,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
