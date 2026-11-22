import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../components/modern_card.dart';
import '../../config/theme.dart';
import '../../l10n/app_localizations.dart';
import '../../services/connection_manager_service.dart';

/// LLM Provider Settings Screen — Hermes-focused.
class LLMProviderSettingsScreen extends StatelessWidget {
  const LLMProviderSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.colorsOf(context);
    final l10n = AppLocalizations.of(context);
    final isConnected = context.watch<ConnectionManagerService>().isConnected;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/config'),
          tooltip: l10n.commonBackToSettings,
        ),
        title: Text(l10n.llmProviderSettingsTitle),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      // Scrollable: the cards overflow an 800×600 window (by 50 px in
      // English, more in French).
      body: SingleChildScrollView(
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
                    Text(l10n.llmProviderHermesDescription),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () => context.go('/config'),
                      icon: const Icon(Icons.settings),
                      label: Text(l10n.llmProviderOpenConfig),
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
                      l10n.llmProviderSystemStatus,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    ListTile(
                      leading: Icon(
                        isConnected ? Icons.check_circle : Icons.error_outline,
                        color: isConnected ? colors.success : colors.danger,
                      ),
                      title: const Text('Hermes Agent'),
                      subtitle: Text(l10n.llmProviderPrimaryRuntime),
                      trailing: Text(
                        isConnected
                            ? l10n.commonConnected
                            : l10n.commonDisconnected,
                        style: TextStyle(
                          color: isConnected ? colors.success : colors.danger,
                        ),
                      ),
                    ),
                    ListTile(
                      leading: Icon(Icons.info_outline, color: colors.info),
                      title: Text(l10n.llmProviderSupportProviders),
                      subtitle: Text(l10n.llmProviderSupportProvidersSubtitle),
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
