import 'package:pistisai/features/avatar/avatar_widget.dart';

/// Configuration for Rive animation states mapped to [AgentState].
///
/// Defines the expected state machine inputs for the avatar.riv file.
/// The Rive state machine uses a number input named `state` with values
/// 0–4 corresponding to each [AgentState].
class RiveAnimationConfig {
  /// The name of the artboard in the .riv file.
  static const String artboardName = 'Avatar';

  /// The name of the state machine in the .riv file.
  static const String stateMachineName = 'AvatarStateMachine';

  /// The name of the number input that controls the animation state.
  static const String stateInputName = 'state';

  /// The path to the Rive animation asset.
  static const String assetPath = 'assets/animations/avatar.riv';

  /// Maps an [AgentState] to its numeric input value for the Rive state machine.
  static int stateToInput(AgentState state) {
    switch (state) {
      case AgentState.idle:
        return 0;
      case AgentState.thinking:
        return 1;
      case AgentState.working:
        return 2;
      case AgentState.error:
        return 3;
      case AgentState.happy:
        return 4;
    }
  }

  /// Returns the display name for a given [AgentState].
  static String stateDisplayName(AgentState state) {
    switch (state) {
      case AgentState.idle:
        return 'Idle';
      case AgentState.thinking:
        return 'Thinking';
      case AgentState.working:
        return 'Working';
      case AgentState.error:
        return 'Error';
      case AgentState.happy:
        return 'Happy';
    }
  }

  /// All supported states in display order.
  static List<AgentState> get allStates =>
      [AgentState.idle, AgentState.thinking, AgentState.working, AgentState.error, AgentState.happy];

  /// Whether the .riv asset is expected to be available.
  /// Returns false when the asset file does not exist, allowing graceful fallback.
  static bool get isAvailable => false; // Will be set to true once avatar.riv is created
}
