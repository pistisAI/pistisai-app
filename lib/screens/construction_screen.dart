import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../config/theme.dart';

/// Construction Page - Shows current features with progress and roadmap
class ConstructionScreen extends StatelessWidget {
  const ConstructionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Construction'),
        elevation: 0,
        leading: BackButton(
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/config'),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status Banner
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Theme.of(context).colorScheme.primary,
                    Theme.of(context).colorScheme.secondary,
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.bolt,
                          color: AppTheme.colorsOf(context).textColor,
                          size: 24),
                      SizedBox(width: 12),
                      Text(
                        'Beta / Active Development',
                        style: TextStyle(
                          color: AppTheme.colorsOf(context).textColor,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Text(
                    'We are building something amazing. Check back soon!',
                    style: TextStyle(
                      color: AppTheme.colorsOf(context)
                          .textColor
                          .withValues(alpha: 0.7),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Current Features
            Text(
              'Current Features',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),

            _buildFeatureCard(
              context,
              title: 'Desktop hub',
              description:
                  'This computer is the hub. Web, mobile, and other desktops connect through it.',
              progress: 100,
              icon: Icons.dashboard,
              color: AppTheme.colorsOf(context).info,
            ),
            const SizedBox(height: 12),

            _buildFeatureCard(
              context,
              title: 'Agent on this computer',
              description:
                  'Hermes-based agent and skills. No special hardware. Online models only when you allow them.',
              progress: 100,
              icon: Icons.memory,
              color: AppTheme.colorsOf(context).success,
            ),
            const SizedBox(height: 12),

            _buildFeatureCard(
              context,
              title: 'Your data',
              description:
                  'Stays on this computer unless you agree to a cloud service. Quebec delivery follows Law 25.',
              progress: 100,
              icon: Icons.shield,
              color: AppTheme.colorsOf(context).accent,
            ),
            const SizedBox(height: 12),

            _buildFeatureCard(
              context,
              title: 'Where to open it',
              description:
                  'Linux, Windows, macOS, and Android from CI. Web app at app.pistisai.app.',
              progress: 100,
              icon: Icons.devices,
              color: AppTheme.colorsOf(context).warning,
            ),
            const SizedBox(height: 32),

            // Roadmap Timeline
            Text(
              'Roadmap',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),

            _buildRoadmapCard(
              context,
              title: 'Desktop hub',
              description:
                  'The app on this computer connects to the agent. Other devices use that hub.',
              date: 'Now',
              isCompleted: true,
              items: const [
                'Hermes-based agent and skills',
                'Voice, vision, and permissioned desktop actions',
                'No special hardware',
              ],
            ),
            const SizedBox(height: 12),

            _buildRoadmapCard(
              context,
              title: 'Tunnel and sync',
              description:
                  'Sign-in exists only for tunnel and sync. Local use does not require an account.',
              date: 'Now',
              isCompleted: true,
              items: const [
                'Free: pistisai.app tunnel, Cloudflare Access',
                'Business and Enterprise: your Tailscale network or VPN',
              ],
            ),
            const SizedBox(height: 12),

            _buildRoadmapCard(
              context,
              title: 'Quebec delivery',
              description:
                  'IAClé delivers this same stack to Quebec businesses, including regulated SMBs.',
              date: 'Now',
              isCompleted: true,
              items: const [
                'One stack, one company',
                'Cloud and online models only with consent and Law 25',
              ],
            ),
            const SizedBox(height: 32),

            // Quick Links
            Text(
              'Quick Links',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),

            _buildLinkCard(
              context,
              title: 'GitHub Repository',
              description: 'View code, report issues, contribute',
              url: 'https://github.com/pistisAI/pistisai-app',
              icon: Icons.code,
            ),
            const SizedBox(height: 12),

            _buildLinkCard(
              context,
              title: 'Documentation',
              description: 'Product page and guides in the repository',
              url:
                  'https://github.com/pistisAI/pistisai-app/blob/main/docs/PRODUCT.md',
              icon: Icons.book,
            ),
            const SizedBox(height: 12),

            _buildLinkCard(
              context,
              title: 'Issues',
              description: 'Report a problem or a real use case',
              url: 'https://github.com/pistisAI/pistisai-app/issues',
              icon: Icons.bug_report,
            ),
            const SizedBox(height: 32),

            // Back Button
            Center(
              child: ElevatedButton.icon(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.arrow_back),
                label: const Text('Back to App'),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureCard(
    BuildContext context, {
    required String title,
    required String description,
    required int progress,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        description,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            LinearProgressIndicator(
              value: progress / 100,
              backgroundColor:
                  Theme.of(context).colorScheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                '$progress%',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoadmapCard(
    BuildContext context, {
    required String title,
    required String description,
    required String date,
    required bool isCompleted,
    required List<String> items,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isCompleted
                        ? AppTheme.colorsOf(context)
                            .success
                            .withValues(alpha: 0.1)
                        : AppTheme.colorsOf(context)
                            .info
                            .withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    isCompleted ? Icons.check_circle : Icons.event,
                    color: isCompleted
                        ? AppTheme.colorsOf(context).success
                        : AppTheme.colorsOf(context).info,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                      ),
                      Text(
                        date,
                        style: TextStyle(
                          fontSize: 12,
                          color: isCompleted
                              ? AppTheme.colorsOf(context).success
                              : AppTheme.colorsOf(context).info,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              description,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            ...items.map((item) => Padding(
                  padding: const EdgeInsets.only(left: 12, bottom: 4),
                  child: Row(
                    children: [
                      Icon(
                        isCompleted
                            ? Icons.check_circle
                            : Icons.circle_outlined,
                        size: 16,
                        color: isCompleted
                            ? AppTheme.colorsOf(context).success
                            : AppTheme.colorsOf(context).textColorLight,
                      ),
                      const SizedBox(width: 8),
                      Text(item),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildLinkCard(
    BuildContext context, {
    required String title,
    required String description,
    required String url,
    required IconData icon,
  }) {
    return Card(
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: Theme.of(context).colorScheme.primary),
        ),
        title: Text(title),
        subtitle: Text(description),
        trailing: Icon(
          Icons.chevron_right,
          color: Theme.of(context).colorScheme.outline,
        ),
        onTap: () {
          // Open link in new tab
          // In Flutter web, this works; in desktop apps, it might need platform-specific code
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Opening $url...'),
              duration: const Duration(seconds: 2),
            ),
          );
        },
      ),
    );
  }
}
