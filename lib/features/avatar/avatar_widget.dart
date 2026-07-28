import 'package:flutter/material.dart';
import 'package:pistisai/models/avatar/personality_models.dart';
import 'package:pistisai/features/avatar/emoji_blending_avatar.dart';

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
/// Uses [EmojiBlendingAvatar] as the default rendering engine with smooth
/// cross-fade transitions between states. Designed to be swapped for a
/// Rive (.riv) animation engine when available.
class AgentAvatar extends StatelessWidget {
  final AgentState state;
  final double size;
  final PersonalityTraits? personality;

  const AgentAvatar({
    super.key,
    required this.state,
    this.size = 150,
    this.personality,
  });

  @override
  Widget build(BuildContext context) {
    return EmojiBlendingAvatar(
      state: state,
      size: size,
      personality: personality,
    );
  }
}
