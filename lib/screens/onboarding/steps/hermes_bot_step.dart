import 'package:flutter/material.dart';

/// Shown on the first local Hermes setup. Completing the wizard installs
/// the pistisai package into the Hermes that was just connected.
class HermesBotStep extends StatelessWidget {
  const HermesBotStep({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'PistisAI package',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 12),
          Text(
            'Finishing this first-time setup installs the pistisai package '
            'into the Hermes you just connected. That home comes from that '
            'Hermes, including when it is not the usual Windows location. '
            'The package adds the aigent-watch bot, the drift-scan skill, '
            'and a routine that runs every 6 hours.',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ],
      ),
    );
  }
}
