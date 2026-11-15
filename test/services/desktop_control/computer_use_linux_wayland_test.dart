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

    test('screenshot raise_window tool description documents focus when false', () {
      final description =
          ComputerUseLinuxWayland.screenshotRaiseWindowToolDescription;
      expect(description, contains('default true'));
      expect(description, contains('raise_window=false'));
      expect(description, contains('already be focused'));
      expect(description, contains('activate_window'));
    });

    group('type_text landing verification (#680)', () {
      test('ok alone without AT-SPI readback is unverifiable', () {
        expect(
          ComputerUseLinuxWayland.classifyTypeTextLanding(
            ok: true,
            typedText: 'hello',
          ),
          TypeTextLanding.unverifiable,
        );
      });

      test('ok with empty AT-SPI character count is verified-lost', () {
        expect(
          ComputerUseLinuxWayland.classifyTypeTextLanding(
            ok: true,
            typedText: 'hello',
            atSpiCharacterCount: 0,
          ),
          TypeTextLanding.lost,
        );
      });

      test('ok when focused field contains typed text is verified', () {
        expect(
          ComputerUseLinuxWayland.classifyTypeTextLanding(
            ok: true,
            typedText: 'hello',
            atSpiCharacterCount: 5,
            focusedFieldText: 'hello',
          ),
          TypeTextLanding.verified,
        );
      });

      test('ok when focused field omits typed text is lost', () {
        expect(
          ComputerUseLinuxWayland.classifyTypeTextLanding(
            ok: true,
            typedText: 'hello',
            atSpiCharacterCount: 3,
            focusedFieldText: 'hey',
          ),
          TypeTextLanding.lost,
        );
      });

      test('failed dispatch is failed', () {
        expect(
          ComputerUseLinuxWayland.classifyTypeTextLanding(
            ok: false,
            typedText: 'hello',
            atSpiCharacterCount: 0,
          ),
          TypeTextLanding.failed,
        );
      });

      test('verification guidance requires include_tree or re-observe', () {
        final note = ComputerUseLinuxWayland.typeTextVerificationGuidance;
        expect(note, contains('include_tree'));
        expect(note, contains('set_value'));
        expect(note, contains('dispatch'));
      });

      test('recommended type_text args request AT-SPI tree for verification', () {
        expect(
          ComputerUseLinuxWayland.typeTextVerificationArgs['include_tree'],
          isTrue,
        );
      });
    });
  });
}
