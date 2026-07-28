import 'package:flutter/material.dart';
import 'package:pistisai/models/avatar/personality_models.dart';
import 'package:pistisai/features/avatar/avatar_widget.dart';

/// An emoji-based avatar with smooth blending transitions between states.
///
/// Designed as a fallback when Rive (.riv) animations are not available.
/// Provides personality-aware emoji selection with configurable size and
/// animation speed.
class EmojiBlendingAvatar extends StatefulWidget {
  /// The current agent state to display.
  final AgentState state;

  /// The size of the avatar (diameter in logical pixels).
  final double size;

  /// Optional personality traits for dynamic emoji selection.
  final PersonalityTraits? personality;

  /// Duration of the cross-fade transition between emoji states.
  final Duration transitionDuration;

  /// Duration of the idle pulse animation cycle.
  final Duration pulseDuration;

  /// Whether to show a pulsing glow effect.
  final bool showGlow;

  const EmojiBlendingAvatar({
    super.key,
    required this.state,
    this.size = 150,
    this.personality,
    this.transitionDuration = const Duration(milliseconds: 400),
    this.pulseDuration = const Duration(seconds: 2),
    this.showGlow = true,
  });

  @override
  State<EmojiBlendingAvatar> createState() => _EmojiBlendingAvatarState();
}

class _EmojiBlendingAvatarState extends State<EmojiBlendingAvatar>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _bounceController;

  // Personality-derived properties
  Color _baseColor = Colors.blue;
  double _bounceScale = 1.0;
  bool _isPulsing = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: widget.pulseDuration,
    )..repeat(reverse: true);

    _bounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _updatePersonalityDerived();
  }

  @override
  void didUpdateWidget(EmojiBlendingAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.state != oldWidget.state) {
      _onStateChanged(widget.state);
    }

    if (widget.personality != oldWidget.personality) {
      _updatePersonalityDerived();
    }

    if (widget.pulseDuration != oldWidget.pulseDuration) {
      _pulseController.duration = widget.pulseDuration;
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _bounceController.dispose();
    super.dispose();
  }

  void _updatePersonalityDerived() {
    final traits = widget.personality;
    _baseColor = _getPersonalityColor(traits);
    _bounceScale = _getBounceScale(traits);
    _isPulsing = widget.state == AgentState.thinking ||
        widget.state == AgentState.working;
  }

  void _onStateChanged(AgentState newState) {
    _updatePersonalityDerived();

    // Trigger bounce animation on state change
    _bounceController
      ..reset()
      ..forward();

    // Update pulse based on new state
    _isPulsing = newState == AgentState.thinking ||
        newState == AgentState.working;
  }

  Color _getPersonalityColor(PersonalityTraits? traits) {
    if (traits == null) {
      final theme = Theme.of(context);
      return theme.primaryColor;
    }

    // Hue from empathy (blue 220° → warm 180°)
    final hue = 220 - (traits.empathy * 40);

    // Saturation from enthusiasm (muted 0.5 → vibrant 1.0)
    final saturation = 0.5 + (traits.enthusiasm * 0.5);

    // Lightness from humor (darker 0.4 → brighter 0.6)
    final lightness = 0.4 + (traits.humor * 0.2);

    return HSLColor.fromAHSL(1.0, hue, saturation, lightness).toColor();
  }

  double _getBounceScale(PersonalityTraits? traits) {
    if (traits == null) return 1.0;
    // Humor controls bounce (1.0 → 1.2)
    return 1.0 + (traits.humor * 0.2);
  }

  /// Returns the emoji for the given state, optionally influenced by personality.
  String _getEmojiForState(AgentState state, PersonalityTraits? traits) {
    if (traits == null) {
      return _getDefaultEmoji(state);
    }

    // Trait-based emoji selection
    if (traits.humor > 0.7) {
      switch (state) {
        case AgentState.idle:
          return '😜';
        case AgentState.thinking:
          return '🤪';
        case AgentState.working:
          return '⚡';
        case AgentState.error:
          return '💥';
        case AgentState.happy:
          return '🎉';
      }
    }

    if (traits.empathy > 0.8) {
      switch (state) {
        case AgentState.idle:
          return '🤗';
        case AgentState.thinking:
          return '💭';
        case AgentState.working:
          return '💪';
        case AgentState.error:
          return '😢';
        case AgentState.happy:
          return '🥰';
      }
    }

    if (traits.formality > 0.7) {
      switch (state) {
        case AgentState.idle:
          return '🎩';
        case AgentState.thinking:
          return '🧐';
        case AgentState.working:
          return '📊';
        case AgentState.error:
          return '⚠️';
        case AgentState.happy:
          return '✅';
      }
    }

    if (traits.enthusiasm > 0.7) {
      switch (state) {
        case AgentState.idle:
          return '🌟';
        case AgentState.thinking:
          return '💡';
        case AgentState.working:
          return '🚀';
        case AgentState.error:
          return '😵';
        case AgentState.happy:
          return '🎊';
      }
    }

    return _getDefaultEmoji(state);
  }

  String _getDefaultEmoji(AgentState state) {
    switch (state) {
      case AgentState.idle:
        return '🦞';
      case AgentState.thinking:
        return '🤔';
      case AgentState.working:
        return '⚡';
      case AgentState.error:
        return '💢';
      case AgentState.happy:
        return '✨';
    }
  }

  /// Returns a background color tint for the given state.
  Color _getStateColor(AgentState state) {
    switch (state) {
      case AgentState.idle:
        return _baseColor.withValues(alpha: 0.1);
      case AgentState.thinking:
        return Colors.purple.withValues(alpha: 0.1);
      case AgentState.working:
        return Colors.orange.withValues(alpha: 0.1);
      case AgentState.error:
        return Colors.red.withValues(alpha: 0.15);
      case AgentState.happy:
        return Colors.green.withValues(alpha: 0.1);
    }
  }

  /// Returns a border color for the given state.
  Color _getStateBorderColor(AgentState state) {
    switch (state) {
      case AgentState.idle:
        return _baseColor.withValues(alpha: 0.5);
      case AgentState.thinking:
        return Colors.purple.withValues(alpha: 0.5);
      case AgentState.working:
        return Colors.orange.withValues(alpha: 0.5);
      case AgentState.error:
        return Colors.red.withValues(alpha: 0.7);
      case AgentState.happy:
        return Colors.green.withValues(alpha: 0.5);
    }
  }

  /// Returns a glow shadow color for the given state.
  Color _getStateGlowColor(AgentState state) {
    switch (state) {
      case AgentState.idle:
        return _baseColor.withValues(alpha: 0.3);
      case AgentState.thinking:
        return Colors.purple.withValues(alpha: 0.3);
      case AgentState.working:
        return Colors.orange.withValues(alpha: 0.3);
      case AgentState.error:
        return Colors.red.withValues(alpha: 0.4);
      case AgentState.happy:
        return Colors.green.withValues(alpha: 0.3);
    }
  }

  @override
  Widget build(BuildContext context) {
    final emoji = _getEmojiForState(widget.state, widget.personality);
    final bgColor = _getStateColor(widget.state);
    final borderColor = _getStateBorderColor(widget.state);
    final glowColor = _getStateGlowColor(widget.state);

    return AnimatedBuilder(
      animation: Listenable.merge([_pulseController, _bounceController]),
      builder: (context, child) {
        // Pulse animation: oscillate between 0.95 and 1.05
        final pulse = _isPulsing ? (0.95 + (_pulseController.value * 0.1)) : 1.0;

        // Bounce animation: quick scale up then back
        final bounce = _bounceController.isAnimating
            ? TweenSequence<double>([
                TweenSequenceItem(
                  tween: Tween(begin: 1.0, end: 1.15),
                  weight: 40,
                ),
                TweenSequenceItem(
                  tween: Tween(begin: 1.15, end: 1.0),
                  weight: 60,
                ),
              ]).evaluate(_bounceController)
            : 1.0;

        final totalScale = pulse * bounce * _bounceScale;

        return AnimatedContainer(
          duration: widget.transitionDuration,
          curve: Curves.easeInOut,
          width: widget.size * totalScale,
          height: widget.size * totalScale,
          decoration: BoxDecoration(
            color: bgColor,
            shape: BoxShape.circle,
            border: Border.all(
              color: borderColor,
              width: 4,
            ),
            boxShadow: widget.showGlow
                ? [
                    BoxShadow(
                      color: glowColor,
                      blurRadius: 20 * pulse,
                      spreadRadius: 5 * pulse,
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: AnimatedSwitcher(
              duration: widget.transitionDuration,
              switchInCurve: Curves.easeOutBack,
              switchOutCurve: Curves.easeIn,
              transitionBuilder: (Widget child, Animation<double> animation) {
                return FadeTransition(
                  opacity: animation,
                  child: ScaleTransition(
                    scale: Tween<double>(begin: 0.5, end: 1.0)
                        .animate(CurvedAnimation(
                      parent: animation,
                      curve: Curves.elasticOut,
                    )),
                    child: child,
                  ),
                );
              },
              child: Text(
                emoji,
                key: ValueKey('${emoji}_${widget.state.name}'),
                style: TextStyle(
                  fontSize: widget.size * 0.5,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
