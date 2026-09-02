import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../config/theme.dart';
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Appearance'),
        elevation: 0,
        leading: BackButton(
          onPressed: () {
            context.go('/');
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
                Text('Appearance Settings',
                    style: theme.textTheme.headlineMedium),
                const SizedBox(height: 16),
                const Text('Customize the look and feel of the application.'),
                const SizedBox(height: 32),

                // Theme Mode
                Card(
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.light_mode),
                        title: const Text('Theme Mode'),
                        subtitle: Text(
                          themeProvider.isDarkMode ? 'Dark' : 'Light',
                        ),
                      ),
                      OverflowBar(
                        children: [
                          TextButton(
                            onPressed: () =>
                                themeProvider.setThemeMode(ThemeMode.light),
                            child: const Text('Light'),
                          ),
                          TextButton(
                            onPressed: () =>
                                themeProvider.setThemeMode(ThemeMode.dark),
                            child: const Text('Dark'),
                          ),
                          TextButton(
                            onPressed: () =>
                                themeProvider.setThemeMode(ThemeMode.system),
                            child: const Text('System'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),

                // Accent Color
                Card(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(Icons.color_lens),
                          title: Text('Accent Color'),
                          subtitle: Text('Used as the app color scheme seed'),
                        ),
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            for (final option in _accentOptions)
                              _AccentSwatch(
                                color: option.color,
                                label: option.label,
                                selected:
                                    themeProvider.accentColor == option.color,
                                onTap: () =>
                                    themeProvider.setAccentColor(option.color),
                              ),
                          ],
                        ),
                      ],
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

class _AccentOption {
  const _AccentOption(this.label, this.color);
  final String label;
  final Color color;
}

const _accentOptions = [
  _AccentOption('Gold', Color(0xFFFFD700)),
  _AccentOption('Warm gold', Color(0xFFD4A017)),
  _AccentOption('Teal', Color(0xFF26A69A)),
  _AccentOption('Blue', Color(0xFF42A5F5)),
  _AccentOption('Coral', Color(0xFFFF7043)),
  _AccentOption('Purple', Color(0xFFAB47BC)),
];

class _AccentSwatch extends StatelessWidget {
  const _AccentSwatch({
    required this.color,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final Color color;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Column(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(
                color: selected
                    ? Theme.of(context).colorScheme.onSurface
                    : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(label, style: Theme.of(context).textTheme.labelSmall),
        ],
      ),
    );
  }
}
