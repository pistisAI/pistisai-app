import 'package:flutter/material.dart';

/// Welcome step - First screen of the setup wizard
class WelcomeStep extends StatelessWidget {
  const WelcomeStep({super.key});

  static bool _isCompact(double maxHeight) => maxHeight < 620;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = _isCompact(constraints.maxHeight);
        final padding = compact ? 16.0 : 24.0;
        final sectionGap = compact ? 12.0 : 20.0;
        final avatarSize = compact ? 72.0 : 96.0;

        return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(padding, padding, padding, padding + 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(child: _AvatarCircle(size: avatarSize)),
              SizedBox(height: sectionGap),
              const Center(child: _TitleText()),
              SizedBox(height: compact ? 8 : 12),
              const Center(child: _SubtitleText()),
              SizedBox(height: sectionGap),
              _FeatureCards(compact: compact),
              SizedBox(height: sectionGap),
              const _InfoBox(),
            ],
          ),
        );
      },
    );
  }
}

class _AvatarCircle extends StatelessWidget {
  const _AvatarCircle({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
        shape: BoxShape.circle,
      ),
      child: Icon(
        Icons.rocket_launch,
        size: size * 0.55,
        color: Theme.of(context).primaryColor,
      ),
    );
  }
}

class _TitleText extends StatelessWidget {
  const _TitleText();

  @override
  Widget build(BuildContext context) {
    return Text(
      'Welcome to Pistisai',
      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
      textAlign: TextAlign.center,
    );
  }
}

class _SubtitleText extends StatelessWidget {
  const _SubtitleText();

  @override
  Widget build(BuildContext context) {
    return Text(
      'Your privacy-first local AI companion',
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: Colors.grey.shade600,
          ),
      textAlign: TextAlign.center,
    );
  }
}

class _FeatureCards extends StatelessWidget {
  const _FeatureCards({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: compact ? 10 : 16,
      runSpacing: compact ? 10 : 16,
      children: [
        _FeatureCard(
          compact: compact,
          icon: Icons.chat_bubble_outline,
          title: 'Chat',
          description: 'Streaming AI responses',
        ),
        _FeatureCard(
          compact: compact,
          icon: Icons.hub_outlined,
          title: 'Agent Runtimes',
          description: 'Hermes, OpenClaw, and compatible gateways',
        ),
        _FeatureCard(
          compact: compact,
          icon: Icons.face_outlined,
          title: 'Evolving Avatar',
          description: 'Personalized AI companion',
        ),
        _FeatureCard(
          compact: compact,
          icon: Icons.desktop_windows_outlined,
          title: 'Desktop Control',
          description: 'GUI automation',
        ),
        _FeatureCard(
          compact: compact,
          icon: Icons.visibility_outlined,
          title: 'Vision',
          description: 'Screen understanding',
        ),
      ],
    );
  }
}

class _InfoBox extends StatelessWidget {
  const _InfoBox();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(Icons.info_outline, color: Colors.blue.shade700, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'We\'ll set up your local AI in about 2 minutes. All processing happens privately on your computer.',
              style: TextStyle(color: Colors.blue.shade900, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  final bool compact;
  final IconData icon;
  final String title;
  final String description;

  const _FeatureCard({
    required this.compact,
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    final cardWidth = compact ? 118.0 : 140.0;
    final cardPadding = compact ? 10.0 : 16.0;
    final iconSize = compact ? 24.0 : 32.0;

    return Container(
      width: cardWidth,
      padding: EdgeInsets.all(cardPadding),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).dividerColor,
        ),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            size: iconSize,
            color: Theme.of(context).primaryColor,
          ),
          SizedBox(height: compact ? 6 : 8),
          Text(
            title,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: compact ? 12 : null,
                ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: compact ? 2 : 4),
          Text(
            description,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontSize: compact ? 11 : null,
                  height: 1.2,
                ),
            textAlign: TextAlign.center,
            maxLines: compact ? 3 : null,
          ),
        ],
      ),
    );
  }
}
