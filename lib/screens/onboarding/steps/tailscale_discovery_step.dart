import 'package:pistisai/config/app_config.dart';
import 'package:flutter/material.dart';
import '../../../l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import 'package:pistisai/services/onboarding/setup_wizard_service.dart';
import 'package:pistisai/services/provider_discovery_service.dart';
import '../../../config/theme.dart';

/// Tailscale Device Discovery Step
/// Discovers and lists Tailscale devices on the tailnet
class TailscaleDiscoveryStep extends StatefulWidget {
  const TailscaleDiscoveryStep({super.key});

  @override
  State<TailscaleDiscoveryStep> createState() => _TailscaleDiscoveryStepState();
}

class _TailscaleDiscoveryStepState extends State<TailscaleDiscoveryStep> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final wizard = context.read<SetupWizardService>();
      debugPrint(
          '[TailscaleDiscoveryStep] initState - selectedMethod: ${wizard.state.selectedMethod}, hermesLocation: ${wizard.state.hermesLocation}');

      final shouldDiscover = wizard.isHermesTailscaleSetup;

      if (shouldDiscover) {
        debugPrint('[TailscaleDiscoveryStep] Starting Tailscale discovery');
        wizard.discoverTailscaleDevices();
      } else {
        debugPrint(
            '[TailscaleDiscoveryStep] Skipping discovery - method is ${wizard.state.selectedMethod}');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SetupWizardService>(
      builder: (context, wizard, child) {
        return Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Header
              if (wizard.state.isLoading) ...[
                const SizedBox(
                  width: 64,
                  height: 64,
                  child: CircularProgressIndicator(),
                ),
                SizedBox(height: 24),
                Text(
                  AppLocalizations.of(context).tailscaleDiscovering,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                SizedBox(height: 8),
                Text(
                  AppLocalizations.of(context).tailscaleScanning,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppTheme.colorsOf(context).textColorLight,
                      ),
                ),
              ] else if (wizard.state.tailscaleDevices.isEmpty) ...[
                _buildNoDevices(context, wizard),
              ] else ...[
                _buildDeviceList(context, wizard),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildNoDevices(BuildContext context, SetupWizardService wizard) {
    return Column(
      children: [
        Icon(
          Icons.lan,
          size: 64,
          color: AppTheme.colorsOf(context).warning,
        ),
        SizedBox(height: 24),
        Text(
          AppLocalizations.of(context).tailscaleNoDevices,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        SizedBox(height: 16),
        Text(
          AppLocalizations.of(context).tailscaleNoDevicesHelp,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppTheme.colorsOf(context).textColorLight,
              ),
        ),
        const SizedBox(height: 24),
        OutlinedButton.icon(
          onPressed: () => wizard.discoverTailscaleDevices(),
          icon: const Icon(Icons.refresh),
          label: Text(AppLocalizations.of(context).commonRetry),
        ),
        const SizedBox(height: 16),
        TextButton.icon(
          onPressed: () => wizard.previousStep(),
          icon: const Icon(Icons.arrow_back),
          label: Text(AppLocalizations.of(context).tailscaleChooseOtherMethod),
        ),
      ],
    );
  }

  Widget _buildDeviceList(BuildContext context, SetupWizardService wizard) {
    return Column(
      children: [
        Icon(
          Icons.lan,
          size: 64,
          color: Theme.of(context).primaryColor,
        ),
        const SizedBox(height: 24),
        Text(
          AppLocalizations.of(context).tailscaleSelectServer,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        SizedBox(height: 8),
        Text(
          AppLocalizations.of(context)
              .tailscaleSelectServerHelp('${AppConfig.defaultHermesPort}'),
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppTheme.colorsOf(context).textColorLight,
              ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 300),
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: wizard.state.tailscaleDevices.length,
            itemBuilder: (context, index) {
              final device = wizard.state.tailscaleDevices[index];
              return _buildDeviceCard(context, device, wizard);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildDeviceCard(
      BuildContext context, TailscaleDevice device, SetupWizardService wizard) {
    final deviceUrl = device.primaryIP != null
        ? 'http://${device.primaryIP}:${AppConfig.defaultHermesPort}'
        : '';
    final isSelected = wizard.state.hermesUrl == deviceUrl;

    return InkWell(
      onTap: () {
        wizard.selectHermesTailscaleDevice(device);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? Theme.of(context).primaryColor.withValues(alpha: 0.1)
              : Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? Theme.of(context).primaryColor
                : Theme.of(context).dividerColor,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: device.isOnline
                    ? AppTheme.colorsOf(context).success.withValues(alpha: 0.1)
                    : AppTheme.colorsOf(context)
                        .textColorLight
                        .withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.computer,
                color: device.isOnline
                    ? AppTheme.colorsOf(context).success
                    : AppTheme.colorsOf(context).textColorLight,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    device.name,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    device.primaryIP ??
                        AppLocalizations.of(context).tailscaleNoIp,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontFamily: 'monospace',
                          color: AppTheme.colorsOf(context).textColorLight,
                        ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(
                Icons.check_circle,
                color: Theme.of(context).primaryColor,
              )
            else
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: device.isOnline
                      ? AppTheme.colorsOf(context)
                          .success
                          .withValues(alpha: 0.1)
                      : AppTheme.colorsOf(context)
                          .textColorLight
                          .withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  device.isOnline
                      ? AppLocalizations.of(context).tailscaleOnline
                      : AppLocalizations.of(context).homeStatusOffline,
                  style: TextStyle(
                    fontSize: 12,
                    color: device.isOnline
                        ? AppTheme.colorsOf(context).success
                        : AppTheme.colorsOf(context).textColorLight,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
