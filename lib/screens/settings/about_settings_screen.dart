import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../brand/brand.dart';
import '../../brand/brand_copy.dart';
import '../../config/app_config.dart';
import '../../config/theme.dart';
import '../../services/agent_display_name.dart';
import '../../widgets/navigation/breadcrumb_bar.dart';

/// About Settings Screen — Pistisai identity, mythology, and 4 pillars
class AboutSettingsScreen extends StatelessWidget {
  const AboutSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final spacing = AppTheme.spacingOf(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(BrandCopy.aboutTitle),
        elevation: 0,
        leading: BackButton(
          onPressed: () => context.go('/config'),
        ),
      ),
      body: Column(
        children: [
          const AutoBreadcrumbBar(),
          Expanded(
            child: ListView(
              padding: EdgeInsets.all(spacing.l),
              children: [
                _buildLogoHeader(context, theme),
                const SizedBox(height: 24),
                _buildSection(
                  context: context,
                  theme: theme,
                  icon: Icons.auto_awesome,
                  title: 'The Vision',
                  child: Text(
                    Brand.current.aboutText,
                    style: theme.textTheme.bodyLarge,
                  ),
                ),
                const SizedBox(height: 24),
                _buildSection(
                  context: context,
                  theme: theme,
                  icon: Icons.flaky,
                  title: 'The Four Pillars',
                  subtitle:
                      'Four Titans held the cosmos aloft at the four corners of the world. ${BrandCopy.pillarsLine}',
                  child: Column(
                    children: [
                      _buildPillarCard(
                        context: context,
                        theme: theme,
                        number: '1',
                        titan: 'Ὑπερίων',
                        titanName: 'Hyperion',
                        direction: 'EAST — Dawn',
                        symbol: '☀️',
                        title: 'AIMAN — The Face',
                        description:
                            '"He who watches from above." God of heavenly light, '
                            'father of the Sun, Moon, and Dawn. The watcher, the welcoming '
                            'presence — ${agentPossessive(configuredAgentName())} face to the world.',
                        color: AppTheme.colorsOf(context).primary,
                      ),
                      const SizedBox(height: 12),
                      _buildPillarCard(
                        context: context,
                        theme: theme,
                        number: '2',
                        titan: 'Κοῖος',
                        titanName: 'Coeus',
                        direction: 'NORTH — Axis',
                        symbol: '⚙️',
                        title: 'AIGENT — The Engine',
                        description:
                            '"Query / Questioning." God of intellect, the axis of '
                            'heaven around which the constellations turn. The mind, the '
                            'engine — ${agentPossessive(configuredAgentName())} capability to reason and execute.',
                        color: AppTheme.colorsOf(context).secondary,
                      ),
                      const SizedBox(height: 12),
                      _buildPillarCard(
                        context: context,
                        theme: theme,
                        number: '3',
                        titan: 'Κρεῖος',
                        titanName: 'Crius',
                        direction: 'SOUTH — Measure',
                        symbol: '✦',
                        title: 'AIDRATION — The Flow',
                        description:
                            '"The Ram / Master." God of constellations, measurement, '
                            'and the cycles of time. The order, the rhythm — ${agentPossessive(configuredAgentName())} '
                            'orchestration of complexity.',
                        color: AppTheme.colorsOf(context).accent,
                      ),
                      const SizedBox(height: 12),
                      _buildPillarCard(
                        context: context,
                        theme: theme,
                        number: '4',
                        titan: 'Ἰαπετός',
                        titanName: 'Iapetus',
                        direction: 'WEST — Craft',
                        symbol: '🔥',
                        title: 'AIMOTIONS — The Heart',
                        description:
                            '"The Piercer." Father of Prometheus (forethought), '
                            'Epimetheus (afterthought), and Atlas (endurance). The wound '
                            'that creates — ${agentPossessive(configuredAgentName())} emotional core and humanity.',
                        color: AppTheme.colorsOf(context).danger,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                _buildSection(
                  context: context,
                  theme: theme,
                  icon: Icons.account_balance,
                  title: 'The Stoa Poikile',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'In ancient Athens, the Stoa Poikile (Painted Portico) stood on the '
                        'Agora — a covered walkway adorned with four great paintings celebrating '
                        'Athenian victories. It was here that Zeno founded Stoicism, the '
                        'philosophy of virtue through reason.',
                        style: theme.textTheme.bodyLarge,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${BrandCopy.stoaLine}each telling its own story: the face (Aiman), the engine (Aigent), '
                        'the heart (Aimotions), and the flow (Aidration). Together they '
                        'create a place where trust can return.',
                        style: theme.textTheme.bodyLarge,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                if (Brand.current.id == 'pistisai')
                  _buildSection(
                    context: context,
                    theme: theme,
                    icon: Icons.science_outlined,
                    title: 'The Myth of Pistis',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Pistis (Πίστις) was the spirit of trust, honesty, and good faith. '
                          'When Pandora opened the forbidden jar, all the evils of the world '
                          'escaped — but so did the good spirits, including Pistis. '
                          'She fled straight back to Olympus, abandoning humanity.',
                          style: theme.textTheme.bodyLarge,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'The poet Theognis wrote: "Pistis (Trust), a mighty god, has gone... '
                          'the race of pious men has perished."',
                          style: theme.textTheme.bodyLarge?.copyWith(
                            fontStyle: FontStyle.italic,
                            color: AppTheme.colorsOf(context).textColorLight,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          BrandCopy.existsLine,
                          style: theme.textTheme.bodyLarge,
                        ),
                      ],
                    ),
                  )
                else
                  _buildSection(
                    context: context,
                    theme: theme,
                    icon: Icons.science_outlined,
                    title: 'About',
                    child: Text(
                      BrandCopy.existsLine,
                      style: theme.textTheme.bodyLarge,
                    ),
                  ),
                const SizedBox(height: 32),
                // App info
                Card(
                  color: theme.colorScheme.surface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.borderRadiusM),
                    side: BorderSide(
                      color: theme.colorScheme.primary.withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(spacing.m),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('App Information',
                            style: theme.textTheme.titleMedium),
                        const SizedBox(height: 12),
                        _buildInfoRow(context, 'Version', AppConfig.appVersion),
                        _buildInfoRow(context, 'Repository',
                            Brand.current.repositoryLabel),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 48),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogoHeader(BuildContext context, ThemeData theme) {
    return Center(
      child: Column(
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppTheme.colorsOf(context).secondary,
                  AppTheme.colorsOf(context).primary
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color:
                      AppTheme.colorsOf(context).primary.withValues(alpha: 0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipOval(
              child: Image.asset(
                Brand.current.iconAsset,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Center(
                  child: Text(
                      Brand.current.shortName.isEmpty
                          ? '?'
                          : Brand.current.shortName[0],
                      style: TextStyle(
                          fontSize: 48,
                          color: AppTheme.colorsOf(context).textColor)),
                ),
              ),
            ),
          ),
          if (Brand.current.greekWordmark.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              Brand.current.greekWordmark,
              style: theme.textTheme.headlineLarge?.copyWith(
                letterSpacing: 6,
                color: AppTheme.colorsOf(context).primary,
              ),
            ),
          ],
          const SizedBox(height: 4),
          Text(
            Brand.current.wordmark,
            style: theme.textTheme.bodyMedium?.copyWith(
              letterSpacing: 4,
              color: AppTheme.colorsOf(context).textColorLight,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection({
    required BuildContext context,
    required ThemeData theme,
    required IconData icon,
    required String title,
    String? subtitle,
    required Widget child,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: AppTheme.colorsOf(context).primary, size: 20),
            const SizedBox(width: 8),
            Text(
              title,
              style: theme.textTheme.titleLarge?.copyWith(
                color: AppTheme.colorsOf(context).primary,
              ),
            ),
          ],
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 28),
            child: Text(
              subtitle,
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppTheme.colorsOf(context).textColorLight,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
        const SizedBox(height: 12),
        child,
      ],
    );
  }

  Widget _buildPillarCard({
    required BuildContext context,
    required ThemeData theme,
    required String number,
    required String titan,
    required String titanName,
    required String direction,
    required String symbol,
    required String title,
    required String description,
    required Color color,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.borderRadiusM),
        border: Border.all(
          color: color.withValues(alpha: 0.4),
          width: 1.5,
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Number badge
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withValues(alpha: 0.2),
            ),
            child: Center(
              child: Text(
                number,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Text(symbol, style: const TextStyle(fontSize: 18)),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '$titan ($titanName) · $direction',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: color,
                    fontFamily: 'Georgia, serif',
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  description,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppTheme.colorsOf(context).textColorLight,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style:
                  TextStyle(color: AppTheme.colorsOf(context).textColorLight)),
          Text(value,
              style: TextStyle(color: AppTheme.colorsOf(context).textColor)),
        ],
      ),
    );
  }
}
