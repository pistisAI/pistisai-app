import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../config/app_config.dart';
import '../../config/theme.dart';
import '../../config/theme_config.dart';
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
        title: const Text('About Pistisai'),
        elevation: 0,
        leading: BackButton(
          onPressed: () => context.go('/'),
        ),
      ),
      body: Column(
        children: [
          const AutoBreadcrumbBar(),
          Expanded(
            child: ListView(
              padding: EdgeInsets.all(spacing.l),
              children: [
                _buildLogoHeader(theme),
                const SizedBox(height: 24),
                _buildSection(
                  theme: theme,
                  icon: Icons.auto_awesome,
                  title: 'The Vision',
                  child: Text(
                    'Pistisai brings trust back to artificial intelligence — '
                    'a modern Stoa (portico) where Pistis (Πίστις), the ancient '
                    'spirit of trust and good faith, can dwell among us again.',
                    style: theme.textTheme.bodyLarge,
                  ),
                ),
                const SizedBox(height: 24),
                _buildSection(
                  theme: theme,
                  icon: Icons.flaky,
                  title: 'The Four Pillars',
                  subtitle: 'Four Titans held the cosmos aloft at the four corners of the world. '
                      'Four pillars hold Pistisai together.',
                  child: Column(
                    children: [
                      _buildPillarCard(
                        theme: theme,
                        number: '1',
                        titan: 'Ὑπερίων',
                        titanName: 'Hyperion',
                        direction: 'EAST — Dawn',
                        symbol: '☀️',
                        title: 'AIMAN — The Face',
                        description: '"He who watches from above." God of heavenly light, '
                            'father of the Sun, Moon, and Dawn. The watcher, the welcoming '
                            'presence — Zoid\'s face to the world.',
                        color: ThemeConfig.primaryColor,
                      ),
                      const SizedBox(height: 12),
                      _buildPillarCard(
                        theme: theme,
                        number: '2',
                        titan: 'Κοῖος',
                        titanName: 'Coeus',
                        direction: 'NORTH — Axis',
                        symbol: '⚙️',
                        title: 'AIGENT — The Engine',
                        description: '"Query / Questioning." God of intellect, the axis of '
                            'heaven around which the constellations turn. The mind, the '
                            'engine — Zoid\'s capability to reason and execute.',
                        color: ThemeConfig.secondaryColor,
                      ),
                      const SizedBox(height: 12),
                      _buildPillarCard(
                        theme: theme,
                        number: '3',
                        titan: 'Κρεῖος',
                        titanName: 'Crius',
                        direction: 'SOUTH — Measure',
                        symbol: '✦',
                        title: 'AIDRATION — The Flow',
                        description: '"The Ram / Master." God of constellations, measurement, '
                            'and the cycles of time. The order, the rhythm — Zoid\'s '
                            'orchestration of complexity.',
                        color: ThemeConfig.accentColor,
                      ),
                      const SizedBox(height: 12),
                      _buildPillarCard(
                        theme: theme,
                        number: '4',
                        titan: 'Ἰαπετός',
                        titanName: 'Iapetus',
                        direction: 'WEST — Craft',
                        symbol: '🔥',
                        title: 'AIMOTIONS — The Heart',
                        description: '"The Piercer." Father of Prometheus (forethought), '
                            'Epimetheus (afterthought), and Atlas (endurance). The wound '
                            'that creates — Zoid\'s emotional core and humanity.',
                        color: ThemeConfig.dangerColor,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                _buildSection(
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
                        'Like the Stoa Poikile, Pistisai is a space held up by four pillars, '
                        'each telling its own story: the face (Aiman), the engine (Aigent), '
                        'the heart (Aimotions), and the flow (Aidration). Together they '
                        'create a place where trust can return.',
                        style: theme.textTheme.bodyLarge,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                _buildSection(
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
                          color: ThemeConfig.darkTextColorLight,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Pistisai exists to build a space worthy of Pistis — a Stoa where '
                        'trust can finally return to the world of intelligent machines.',
                        style: theme.textTheme.bodyLarge,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                // App info
                Card(
                  color: AppTheme.backgroundCard,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.borderRadiusM),
                    side: BorderSide(
                      color: AppTheme.primaryColor.withValues(alpha: 0.3),
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
                        _buildInfoRow('Version', AppConfig.appVersion),
                        _buildInfoRow('Repository',
                            'pistisAI/pistisai-app'),
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

  Widget _buildLogoHeader(ThemeData theme) {
    return Center(
      child: Column(
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [ThemeConfig.secondaryColor, ThemeConfig.primaryColor],
              ),
              boxShadow: [
                BoxShadow(
                  color: ThemeConfig.primaryColor.withValues(alpha: 0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipOval(
              child: Image.asset(
                'assets/images/app_icon.png',
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => const Center(
                  child: Text('P',
                      style: TextStyle(fontSize: 48, color: Colors.white)),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'ΠΙΣΤΙΣΑΙ',
            style: theme.textTheme.headlineLarge?.copyWith(
              letterSpacing: 6,
              color: ThemeConfig.primaryColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'PISTISAI',
            style: theme.textTheme.bodyMedium?.copyWith(
              letterSpacing: 4,
              color: ThemeConfig.darkTextColorLight,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection({
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
            Icon(icon, color: ThemeConfig.primaryColor, size: 20),
            const SizedBox(width: 8),
            Text(
              title,
              style: theme.textTheme.titleLarge?.copyWith(
                color: ThemeConfig.primaryColor,
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
                color: ThemeConfig.darkTextColorLight,
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
        color: AppTheme.backgroundCard,
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
                    color: ThemeConfig.darkTextColorLight,
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

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppTheme.textColorLight)),
          Text(value, style: const TextStyle(color: AppTheme.textColor)),
        ],
      ),
    );
  }
}
