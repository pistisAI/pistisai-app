import 'package:flutter/semantics.dart';

/// Wayland gaps for `@agent-sh/computer-use-linux` when driving this app (#616).
///
/// On KDE Plasma / Wayland, computer-use-linux refuses a targeted screenshot when
/// `raise_window=false` unless the window is already focused, and Flutter may
/// expose an empty AT-SPI tree until semantics are forced on. This helper encodes
/// that contract so agents and desktop-control code share one documented policy.
class ComputerUseLinuxWayland {
  ComputerUseLinuxWayland._();

  /// Whether a targeted capture needs an explicit raise/activate first.
  ///
  /// Matches computer-use-linux: `raise_window=false` requires the requested
  /// window to already be focused.
  static bool needsRaiseBeforeTargetedScreenshot({
    required bool raiseWindow,
    required bool windowAlreadyFocused,
  }) {
    if (raiseWindow) {
      return false;
    }
    return !windowAlreadyFocused;
  }

  /// Error text agents see (and should treat as "call activate_window, retry").
  static const String unfocusedTargetScreenshotMessage =
      'raise_window=false requires the requested window to already be focused; '
      'call activate_window (or screenshot with raise_window=true) before '
      'retrying the targeted capture';

  /// Guidance when `accessibility_tree_raw_count` is 0 under linux-atspi.
  static const String atSpiEmptyTreeGuidance =
      'AT-SPI tree empty: call SemanticsBinding.ensureSemantics on Linux so '
      'Flutter publishes the accessibility tree, then activate_window before '
      'get_app_state / targeted screenshot on Wayland';

  /// Force-publish the Flutter semantics tree for AT-SPI clients (Linux).
  ///
  /// Equivalent intent to Chromium's `--force-renderer-accessibility`: keep the
  /// tree available for computer-use-linux even when no screen reader is
  /// registered with the AT-SPI bus (common on KDE Wayland).
  static SemanticsHandle ensureAtSpiSemantics() {
    return SemanticsBinding.instance.ensureSemantics();
  }
}
