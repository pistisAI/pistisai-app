import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../brand/brand.dart';
import '../../config/theme.dart';
import '../../l10n/app_localizations.dart';
import '../../../services/theme_provider.dart';
import 'package:provider/provider.dart';
import '../../widgets/navigation/breadcrumb_bar.dart';

/// Appearance Settings Screen - Theme and visual customization
class AppearanceSettingsScreen extends StatelessWidget {
  const AppearanceSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final spacing = AppTheme.spacingOf(context);
    final themeProvider = context.watch<ThemeProvider>();
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.appearanceScreenTitle),
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
                Text(l10n.settingsAppearanceTitle,
                    style: theme.textTheme.headlineMedium),
                const SizedBox(height: 16),
                Text(l10n.appearanceDescription),
                const SizedBox(height: 32),

                // Theme Mode
                Card(
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.light_mode),
                        title: Text(l10n.appearanceThemeMode),
                        subtitle: Text(
                          themeProvider.isDarkMode
                              ? l10n.themeDark
                              : l10n.themeLight,
                        ),
                      ),
                      OverflowBar(
                        children: [
                          TextButton(
                            onPressed: () =>
                                themeProvider.setThemeMode(ThemeMode.light),
                            child: Text(l10n.themeLight),
                          ),
                          TextButton(
                            onPressed: () =>
                                themeProvider.setThemeMode(ThemeMode.dark),
                            child: Text(l10n.themeDark),
                          ),
                          TextButton(
                            onPressed: () =>
                                themeProvider.setThemeMode(ThemeMode.system),
                            child: Text(l10n.themeSystem),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),

                // Accent Color
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.color_lens),
                    title: Text(l10n.appearanceAccentColor),
                    subtitle: Text(Brand.current.accentLabel),
                    trailing: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: AppTheme.colorsOf(context).accent,
                        shape: BoxShape.circle,
                      ),
                    ),
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
