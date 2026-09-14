import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../components/modern_card.dart';
import '../../config/theme.dart';

/// LLM Provider Settings Screen - OpenClaw focused
///
/// Note: This app uses OpenClaw as the primary LLM engine.
class LLMProviderSettingsScreen extends StatelessWidget {
  const LLMProviderSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.colorsOf(context);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/settings'),
          tooltip: 'Back to Settings',
        ),
        title: const Text('LLM Provider Settings'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ModernCard(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: colors.info,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'OpenClaw Powered',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'This application is powered by OpenClaw. '
                      'All LLM processing, including Chat and Vision-based GUI Automation, '
                      'is handled via your local OpenClaw Gateway.',
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () {
                        // In a real app, this would use the router
                        Navigator.of(context).pushNamed('/gui-automation');
                      },
                      icon: const Icon(Icons.smart_toy),
                      label: const Text('Open GUI Automation'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            ModernCard(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'System Status',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    ListTile(
                      leading: Icon(Icons.check_circle, color: colors.success),
                      title: const Text('OpenClaw Gateway'),
                      subtitle: const Text('Primary LLM provider (Connected)'),
                    ),
                    ListTile(
                      leading: Icon(Icons.check_circle, color: colors.success),
                      title: const Text('GUI Automation'),
                      subtitle: const Text('Vision-based control enabled'),
                    ),
                    ListTile(
                      leading: Icon(Icons.check_circle, color: colors.success),
                      title: const Text('Cloud Relay'),
                      subtitle: const Text('Secure remote access via OpenClaw'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
