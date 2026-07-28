import 'package:flutter/material.dart';
import 'package:pistisai/features/avatar/avatar_widget.dart';
import 'package:pistisai/features/avatar/emoji_blending_avatar.dart';
import 'package:pistisai/features/avatar/rive_animation_config.dart';
import 'package:pistisai/models/avatar/personality_models.dart';

/// A Rive-powered avatar that gracefully falls back to [EmojiBlendingAvatar]
/// when the .riv asset is not yet available.
///
/// Once assets/animations/avatar.riv is created, update [RiveAnimationConfig.isAvailable]
/// to return true and this widget will load and play the Rive animation.
class RiveAvatar extends StatefulWidget {
  /// The current agent state to display.
  final AgentState state;

  /// The size of the avatar (diameter in logical pixels).
  final double size;

  /// Optional personality traits for dynamic color/behavior.
  final PersonalityTraits? personality;

  /// Whether to show a pulsing glow effect (applied to fallback only).
  final bool showGlow;

  const RiveAvatar({
    super.key,
    required this.state,
    this.size = 150,
    this.personality,
    this.showGlow = true,
  });

  @override
  State<RiveAvatar> createState() => _RiveAvatarState();
}

class _RiveAvatarState extends State<RiveAvatar> {
  bool _riveAvailable = false;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _checkRiveAvailability();
  }

  Future<void> _checkRiveAvailability() async {
    // Check if the .riv file is available.
    // Currently returns false since the asset doesn't exist yet.
    // When the .riv file is added, update RiveAnimationConfig.isAvailable.
    setState(() {
      _riveAvailable = RiveAnimationConfig.isAvailable;
      _initialized = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      // Show a minimal placeholder while checking availability
      return SizedBox(
        width: widget.size,
        height: widget.size,
      );
    }

    if (_riveAvailable) {
      // TODO: Implement Rive rendering when the .riv file is available.
      // This will use the rive package:
      //   RiveAnimation.asset(
      //     RiveAnimationConfig.assetPath,
      //     artboard: RiveAnimationConfig.artboardName,
      //     stateMachines: [RiveAnimationConfig.stateMachineName],
      //     fit: BoxFit.contain,
      //   )
      // And set the state input via a controller:
      //   final controller = StateMachineController.fromArtboard(...);
      //   controller?.setNumberInput('state', RiveAnimationConfig.stateToInput(widget.state));
      return _buildFallback();
    }

    return _buildFallback();
  }

  Widget _buildFallback() {
    return EmojiBlendingAvatar(
      state: widget.state,
      size: widget.size,
      personality: widget.personality,
      showGlow: widget.showGlow,
    );
  }
}
