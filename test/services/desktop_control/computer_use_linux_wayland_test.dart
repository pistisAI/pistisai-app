import 'package:flutter_test/flutter_test.dart';
import 'package:pistisai/services/desktop_control/computer_use_linux_wayland.dart';

void main() {
  group('ComputerUseLinuxWayland', () {
    test('targeted screenshot with raise_window=false requires focus', () {
      expect(
        ComputerUseLinuxWayland.needsRaiseBeforeTargetedScreenshot(
          raiseWindow: false,
          windowAlreadyFocused: false,
        ),
        isTrue,
      );
    });

    test('raise_window=true does not require a prior focus step', () {
      expect(
        ComputerUseLinuxWayland.needsRaiseBeforeTargetedScreenshot(
          raiseWindow: true,
          windowAlreadyFocused: false,
        ),
        isFalse,
      );
    });

    test('already-focused window skips raise when raise_window=false', () {
      expect(
        ComputerUseLinuxWayland.needsRaiseBeforeTargetedScreenshot(
          raiseWindow: false,
          windowAlreadyFocused: true,
        ),
        isFalse,
      );
    });

    test('refusal message names the computer-use-linux focus contract', () {
      final message = ComputerUseLinuxWayland.unfocusedTargetScreenshotMessage;
      expect(message, contains('raise_window'));
      expect(message, contains('already be focused'));
      expect(message, contains('activate_window'));
    });

    test('AT-SPI empty-tree note points agents at activate_window workaround', () {
      final note = ComputerUseLinuxWayland.atSpiEmptyTreeGuidance;
      expect(note, contains('AT-SPI'));
      expect(note, contains('activate_window'));
      expect(note, contains('ensureSemantics'));
    });
  });
}
