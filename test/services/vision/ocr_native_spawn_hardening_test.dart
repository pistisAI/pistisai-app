import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guards the native OCR runners against shell-based command construction.
/// Full spawn behavior is platform-native; this asserts the unsafe popen/shell
/// pattern is not reintroduced.
void main() {
  group('native OCR spawn hardening', () {
    test('linux runner does not shell-out via popen with a built command string',
        () {
      final source =
          File('linux/runner/platform_channels.cc').readAsStringSync();
      expect(source, contains('posix_spawnp'));
      expect(source, isNot(contains('popen(cmd.c_str()')));
      expect(source, isNot(contains('cmd += image_path')));
    });

    test('windows runner does not shell-out via _popen with a built command string',
        () {
      final source =
          File('windows/runner/platform_channels.cpp').readAsStringSync();
      expect(source, contains('CreateProcess'));
      expect(source, isNot(contains('_popen(cmd.c_str()')));
      expect(source, isNot(contains('cmd += image_path')));
    });
  });
}
