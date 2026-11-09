import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../config/theme.dart';
import '../../l10n/app_localizations.dart';
import '../../widgets/navigation/breadcrumb_bar.dart';

/// General Settings Screen - Application preferences and configuration
class GeneralSettingsScreen extends StatelessWidget {
  const GeneralSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final spacing = AppTheme.spacingOf(context);
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.settingsGeneralTitle),
        elevation: 0,
        leading: BackButton(
          onPressed: () {
            context.go('/config');
          },
        ),
      ),
      body: Column(
        children: [
          // Breadcrumb navigation
          const AutoBreadcrumbBar(),

          Expanded(
            child: ListView(
              padding: EdgeInsets.all(spacing.l),
              children: [
                Text(l10n.settingsGeneralTitle,
                    style: theme.textTheme.headlineMedium),
                const SizedBox(height: 16),
                Text(l10n.settingsGeneralDescription),
                const SizedBox(height: 32),

                // Theme Setting
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.palette),
                    title: Text(l10n.settingsAppearanceTitle),
                    subtitle: Text(l10n.settingsAppearanceSubtitle),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.go('/settings/appearance'),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
