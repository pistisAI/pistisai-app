import 'package:flutter_test/flutter_test.dart';
import 'package:pistisai/main.dart';

/// Regression tests for [resolveCallbackUrl].
///
/// Guards against the black-screen bug where any command-line argument
/// (e.g. `--enable-logging`, `--verbose`) triggered an early `return` in
/// `main()` before `runApp`, leaving the GTK window unpainted.
void main() {
  group('resolveCallbackUrl', () {
    test('returns null when no args are passed', () {
      expect(resolveCallbackUrl(const []), isNull);
    });

    test('returns null for conventional engine flags', () {
      expect(
        resolveCallbackUrl(const ['--enable-logging', '--verbose']),
        isNull,
      );
    });

    test('returns null for unrelated flags mixed with callback-less args', () {
      expect(
        resolveCallbackUrl(const ['--route=/chat', '--enable-logging']),
        isNull,
      );
    });

    test('returns the pistisai:// callback url when present', () {
      const args = ['--enable-logging', 'pistisai://callback?code=abc'];
      expect(resolveCallbackUrl(args), 'pistisai://callback?code=abc');
    });

    test('returns the com.pistisai.app:// callback url when present', () {
      const args = ['com.pistisai.app://callback?code=xyz', '--verbose'];
      expect(resolveCallbackUrl(args), 'com.pistisai.app://callback?code=xyz');
    });

    test('prefers the first callback url when multiple match', () {
      const args = [
        'pistisai://first',
        'com.pistisai.app://second',
      ];
      expect(resolveCallbackUrl(args), 'pistisai://first');
    });
  });
}
