import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../components/modern_card.dart';
import '../../config/theme.dart';

/// LLM Provider Settings Screen — Hermes-focused.
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
                          'Hermes Agent',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'This application uses Hermes Agent as the primary runtime. '
                      'Chat and related features go through your local Hermes install.',
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () => context.go('/config'),
                      icon: const Icon(Icons.settings),
                      label: const Text('Open Config'),
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
                      title: const Text('Hermes Agent'),
                      subtitle: const Text('Primary agent runtime'),
                    ),
                    ListTile(
                      leading: Icon(Icons.info_outline, color: colors.info),
                      title: const Text('Support model providers'),
                      subtitle: const Text(
                        'Optional helpers such as Ollama or LM Studio',
                      ),
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
