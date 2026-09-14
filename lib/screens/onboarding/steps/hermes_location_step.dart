import 'package:flutter/material.dart';
import '../../../config/theme.dart';
import 'package:provider/provider.dart';
import 'package:pistisai/services/onboarding/setup_wizard_service.dart';
import 'package:pistisai/screens/onboarding/widgets/connection_method_card.dart';

/// Asks where Hermes is running: this device or a Tailscale-reachable server.
class HermesLocationStep extends StatelessWidget {
  const HermesLocationStep({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<SetupWizardService>(
      builder: (context, wizard, child) {
        final selected = wizard.state.hermesLocation;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(
                Icons.place_outlined,
                size: 48,
                color: Theme.of(context).primaryColor,
              ),
              const SizedBox(height: 16),
              Text(
                'Where is Hermes running?',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Hermes can run on this computer or on another machine you reach over Tailscale — including a VPS.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.colorsOf(context).textColorLight,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              ConnectionMethodCard(
                icon: Icons.computer,
                title: 'This device',
                description: 'Hermes is installed and running locally',
                selected: selected == HermesLocation.local,
                onTap: () {
                  wizard.selectHermesLocation(HermesLocation.local);
                },
              ),
              const SizedBox(height: 16),
              ConnectionMethodCard(
                icon: Icons.lan,
                title: 'Tailscale device or VPS',
                description:
                    'Hermes on a home server, VPS, or other machine on your tailnet',
                selected: selected == HermesLocation.tailscale,
                onTap: () {
                  wizard.selectHermesLocation(HermesLocation.tailscale);
                },
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.colorsOf(context).info.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.colorsOf(context).info.withOpacity(0.3)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline, color: AppTheme.colorsOf(context).info, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'For a remote VPS, install Tailscale on the server and this device, then pick the server from your tailnet. Pistisai connects over the private Tailscale IP.',
                        style: TextStyle(
                          color: AppTheme.colorsOf(context).info,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
