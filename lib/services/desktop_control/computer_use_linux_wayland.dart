import 'package:flutter/semantics.dart';

/// Outcome of checking whether `type_text` actually landed (#680).
///
/// computer-use-linux `ok: true` confirms keyboard dispatch only. Agents must
/// re-observe (AT-SPI tree / focused field) before treating input as delivered.
enum TypeTextLanding {
  /// Focused field text contains the typed string.
  verified,

  /// Dispatch succeeded but no AT-SPI readback was available to confirm.
  unverifiable,

  /// Dispatch claimed success, but AT-SPI shows the text did not land.
  lost,

  /// Tool reported `ok: false`.
  failed,
}

/// Wayland gaps for `@agent-sh/computer-use-linux` when driving this app
/// (#616, #680).
///
/// On KDE Plasma / Wayland, computer-use-linux refuses a targeted screenshot when
/// `raise_window=false` unless the window is already focused, and Flutter may
/// expose an empty AT-SPI tree until semantics are forced on. `type_text` may
/// return ok while AT-SPI still shows 0 characters. This helper encodes that
/// contract so agents and desktop-control code share one documented policy.
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

  /// MCP-facing description for the `screenshot.raise_window` parameter (#680).
  ///
  /// Upstream tool schemas omit the focus requirement when the flag is false;
  /// agents driving Pistisai on Wayland must use this wording.
  static const String screenshotRaiseWindowToolDescription =
      'Raise the targeted window before capture (default true). Ignored without '
      'a window target. raise_window=false requires the requested window to '
      'already be focused or the capture fails; call activate_window (or pass '
      'raise_window=true) first.';

  /// Guidance when `accessibility_tree_raw_count` is 0 under linux-atspi.
  static const String atSpiEmptyTreeGuidance =
      'AT-SPI tree empty: call SemanticsBinding.ensureSemantics on Linux so '
      'Flutter publishes the accessibility tree, then activate_window before '
      'get_app_state / targeted screenshot on Wayland';

  /// How agents should verify `type_text` after dispatch (#680).
  static const String typeTextVerificationGuidance =
      'type_text ok confirms keyboard dispatch only, not field content. '
      'Pass include_tree=true (or re-run get_app_state) and require AT-SPI '
      'character count / focused field text to match before treating input as '
      'landed. Prefer set_value when the target exposes EditableText.';

  /// Recommended extra args so a `type_text` call can be verified in-band.
  static const Map<String, Object> typeTextVerificationArgs = <String, Object>{
    'include_tree': true,
  };

  /// Classify whether typed text landed, using AT-SPI observation (#680).
  ///
  /// [atSpiCharacterCount] is the focused editable field's character count from
  /// the post-action tree (0 was observed on KDE Wayland when dispatch lied).
  /// [focusedFieldText] is the field's text value when available.
  static TypeTextLanding classifyTypeTextLanding({
    required bool ok,
    required String typedText,
    int? atSpiCharacterCount,
    String? focusedFieldText,
  }) {
    if (!ok) {
      return TypeTextLanding.failed;
    }
    if (typedText.isEmpty) {
      return TypeTextLanding.verified;
    }
    final String? field = focusedFieldText;
    if (field != null) {
      return field.contains(typedText)
          ? TypeTextLanding.verified
          : TypeTextLanding.lost;
    }
    if (atSpiCharacterCount != null) {
      if (atSpiCharacterCount <= 0) {
        return TypeTextLanding.lost;
      }
      return TypeTextLanding.unverifiable;
    }
    return TypeTextLanding.unverifiable;
  }

  /// Force-publish the Flutter semantics tree for AT-SPI clients (Linux).
  ///
  /// Equivalent intent to Chromium's `--force-renderer-accessibility`: keep the
  /// tree available for computer-use-linux even when no screen reader is
  /// registered with the AT-SPI bus (common on KDE Wayland).
  static SemanticsHandle ensureAtSpiSemantics() {
    return SemanticsBinding.instance.ensureSemantics();
  }
}
