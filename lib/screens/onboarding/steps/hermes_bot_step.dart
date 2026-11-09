import 'package:flutter/material.dart';
import 'package:pistisai/brand/brand.dart';
import 'package:pistisai/brand/brand_copy.dart';
import 'package:pistisai/config/app_config.dart';
import 'package:pistisai/config/theme.dart';
import 'package:pistisai/services/hermes/hermes_bot_install_service.dart';
import 'package:pistisai/services/onboarding/setup_wizard_service.dart';
import 'package:provider/provider.dart';

enum _HermesBotStepPhase { idle, running, done }

/// Shown on the first local Hermes setup. Completing the wizard installs
/// the pistisai package into the Hermes that was just connected.
///
/// On first paint this step runs [HermesBotInstallService.install] and shows
/// progress, then each install step's status and a success/failure summary.
class HermesBotStep extends StatefulWidget {
  const HermesBotStep({
    super.key,
    this.installer,
  });

  /// Override for tests; production uses a fresh [HermesBotInstallService].
  final HermesBotInstallService? installer;

  @override
  State<HermesBotStep> createState() => _HermesBotStepState();
}

class _HermesBotStepState extends State<HermesBotStep> {
  _HermesBotStepPhase _phase = _HermesBotStepPhase.idle;
  HermesBotInstallReport? _report;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _runInstall();
    });
  }

  Future<void> _runInstall() async {
    if (_phase == _HermesBotStepPhase.running) return;

    setState(() {
      _phase = _HermesBotStepPhase.running;
      _report = null;
    });

    // Capture the wizard while mounted so we can still record the report
    // (and clear the loading flag) if the widget is disposed mid-install.
    SetupWizardService? wizard;
    try {
      wizard = context.read<SetupWizardService>();
    } catch (_) {
      wizard = null;
    }

    try {
      wizard?.setBotInstallRunning(true);
    } catch (_) {
      // Wizard may not be available in isolated tests; ignore.
    }

    HermesBotInstallReport report;
    try {
      final installer = widget.installer ?? HermesBotInstallService();
      report = await installer.install(agentPort: _agentPort());
    } catch (error, stackTrace) {
      debugPrint('[HermesBotStep] install failed: $error\n$stackTrace');
      report = HermesBotInstallReport(<HermesBotInstallStep>[
        HermesBotInstallStep(
          name: HermesBotInstallService.agentStep,
          status: HermesBotInstallStatus.failed,
          detail: '$error',
        ),
      ]);
    } finally {
      try {
        wizard?.setBotInstallRunning(false);
      } catch (_) {
        // Wizard may be unavailable; ignore.
      }
    }

    try {
      wizard?.recordBotInstall(report);
    } catch (error, stackTrace) {
      debugPrint(
          '[HermesBotStep] recordBotInstall skipped: $error\n$stackTrace');
    }

    if (!mounted) return;
    setState(() {
      _report = report;
      _phase = _HermesBotStepPhase.done;
    });
  }

  int? _agentPort() {
    final wizard = context.read<SetupWizardService>();
    final uri = Uri.tryParse(wizard.state.hermesUrl?.trim() ?? '');
    if (uri != null && uri.hasPort && uri.port > 0) {
      return uri.port;
    }
    return AppConfig.defaultHermesPort;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              Brand.current.packageTitle,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            Text(
              Brand.current.packageBlurb,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 24),
            if (_phase == _HermesBotStepPhase.running) _buildProgress(context),
            if (_phase == _HermesBotStepPhase.done && _report != null) ...[
              _buildReport(context, _report!),
              const SizedBox(height: 16),
              _buildSummary(context, _report!),
              if (_report!.hasFailures) ...[
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _runInstall,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildProgress(BuildContext context) {
    return Column(
      children: [
        const SizedBox(
          width: 48,
          height: 48,
          child: CircularProgressIndicator(),
        ),
        const SizedBox(height: 16),
        Text(
          BrandCopy.packageInstalling,
          style: Theme.of(context).textTheme.titleMedium,
        ),
      ],
    );
  }

  Widget _buildReport(BuildContext context, HermesBotInstallReport report) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxWidth: 520),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final step in report.steps)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${step.name}: ${_statusLabel(step.status)}',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: _statusColor(context, step.status),
                        ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    step.detail,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppTheme.colorsOf(context).textColorLight,
                        ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSummary(BuildContext context, HermesBotInstallReport report) {
    if (report.succeeded) {
      return Text(
        'Install complete. All steps succeeded or were skipped.',
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: AppTheme.colorsOf(context).success,
              fontWeight: FontWeight.w600,
            ),
      );
    }

    final failed = report.steps
        .where((step) => step.status == HermesBotInstallStatus.failed)
        .toList();
    final failedNames = failed.map((step) => step.name).join(', ');

    return Text(
      'Install failed: $failedNames',
      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: AppTheme.colorsOf(context).danger,
            fontWeight: FontWeight.w600,
          ),
    );
  }

  String _statusLabel(HermesBotInstallStatus status) {
    switch (status) {
      case HermesBotInstallStatus.installed:
        return 'Installed';
      case HermesBotInstallStatus.skipped:
        return 'Skipped';
      case HermesBotInstallStatus.failed:
        return 'Failed';
    }
  }

  Color _statusColor(BuildContext context, HermesBotInstallStatus status) {
    final colors = AppTheme.colorsOf(context);
    switch (status) {
      case HermesBotInstallStatus.installed:
        return colors.success;
      case HermesBotInstallStatus.skipped:
        return colors.textColorLight;
      case HermesBotInstallStatus.failed:
        return colors.danger;
    }
  }
}
