import 'package:flutter/material.dart';
import 'package:pistisai/features/avatar/emoji_blending_avatar.dart';
import 'package:pistisai/models/avatar/personality_models.dart';

/// Represents the current expression/state of the agent.
enum AgentState {
  idle,
  thinking,
  working,
  error,
  happy,
}

/// An expressive avatar for Pistisai that reacts to the agent's state.
///
/// Uses [EmojiBlendingAvatar] for smooth transitions between states.
///
/// This is the primary avatar widget used throughout the app.
class AgentAvatar extends StatelessWidget {
  /// The current agent state to display.
  final AgentState state;

  /// The size of the avatar (diameter in logical pixels).
  final double size;

  /// Optional personality traits for dynamic color/behavior.
  final PersonalityTraits? personality;

  /// Whether to show a pulsing glow effect.
  final bool showGlow;

  const AgentAvatar({
    super.key,
    required this.state,
    this.size = 150,
    this.personality,
    this.showGlow = true,
  });

  @override
  Widget build(BuildContext context) {
    return EmojiBlendingAvatar(
      state: state,
      size: size,
      personality: personality,
      showGlow: showGlow,
    );
  }
}
