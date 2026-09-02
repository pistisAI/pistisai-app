import 'package:flutter/material.dart';
import 'package:pistisai/features/avatar/avatar_widget.dart';
import 'package:pistisai/features/avatar/emoji_blending_avatar.dart';
import 'package:pistisai/features/avatar/rive_animation_config.dart';
import 'package:pistisai/models/avatar/personality_models.dart';
import 'package:rive/rive.dart';

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
  RiveWidgetController? _controller;

  @override
  void initState() {
    super.initState();
    _checkRiveAvailability();
  }

  @override
  void didUpdateWidget(RiveAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.state != oldWidget.state && _controller != null) {
      _setStateInput(widget.state);
    }
  }

  @override
  void dispose() {
    // Controller is disposed by RiveWidgetBuilder
    super.dispose();
  }

  Future<void> _checkRiveAvailability() async {
    setState(() {
      _riveAvailable = RiveAnimationConfig.isAvailable;
      _initialized = true;
    });
  }

  void _onRiveLoaded(RiveLoaded state) {
    _controller = state.controller;
    _setStateInput(widget.state);
  }

  void _setStateInput(AgentState state) {
    final controller = _controller;
    if (controller == null) return;

    // ignore: deprecated_member_use
    final numberInput = controller.stateMachine.number(
      RiveAnimationConfig.stateInputName,
    );
    if (numberInput != null) {
      numberInput.value = RiveAnimationConfig.stateToInput(state).toDouble();
    }
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
      return SizedBox(
        width: widget.size,
        height: widget.size,
        child: RiveWidgetBuilder(
          fileLoader: FileLoader.fromAsset(
            RiveAnimationConfig.assetPath,
            riveFactory: Factory.flutter,
          ),
          artboardSelector: ArtboardSelector.byName(
            RiveAnimationConfig.artboardName,
          ),
          stateMachineSelector: StateMachineSelector.byName(
            RiveAnimationConfig.stateMachineName,
          ),
          onLoaded: _onRiveLoaded,
          onFailed: (error, stackTrace) {
            debugPrint('Rive load failed: $error');
            setState(() {
              _riveAvailable = false;
            });
          },
          builder: (context, state) {
            return switch (state) {
              RiveLoading() => _buildFallback(),
              RiveFailed() => _buildFallback(),
              RiveLoaded(:final controller) => RiveWidget(
                  controller: controller,
                  fit: Fit.contain,
                ),
            };
          },
        ),
      );
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
