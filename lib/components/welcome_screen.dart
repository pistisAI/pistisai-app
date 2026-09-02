import 'package:flutter/material.dart';
import '../config/theme_extensions.dart';

class WelcomeScreen extends StatelessWidget {
  final VoidCallback onNewChat;

  const WelcomeScreen({
    super.key,
    required this.onNewChat,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColorsTheme>()!;
    final theme = Theme.of(context);

    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        constraints: const BoxConstraints(maxWidth: 540),
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 32),
              // Logo with Glow
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: colors.primary.withValues(alpha: 0.25),
                      blurRadius: 40,
                      spreadRadius: 8,
                    ),
                  ],
                ),
                child: Hero(
                  tag: 'app_logo',
                  child: Icon(
                    Icons.auto_awesome,
                    size: 72,
                    color: colors.primary,
                  ),
                ),
              ),
              const SizedBox(height: 28),
              // Title
              Text(
                'Pistisai',
                style: theme.textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colors.textColor,
                  letterSpacing: 0.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              // Subtitle — offline-first positioning
              Text(
                'Your agent companion.\nFully offline until you choose to connect.',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: colors.textColorLight,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              // Offline-first info card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colors.backgroundCard.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: colors.secondary.withValues(alpha: 0.15),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Icon(
                        Icons.info_outline,
                        size: 18,
                        color: colors.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Type a message below or tap /new to start fresh. '
                        'Connect an agent runtime in Settings for AI responses '
                        'and agent features.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.textColorLight,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 48),
            ],
          ),
        ),
      ),
    );
  }
}
