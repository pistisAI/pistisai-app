import 'package:flutter_test/flutter_test.dart';
import 'package:pistisai/config/app_config.dart';
import 'package:pistisai/screens/debug/debug_screen.dart';

void main() {
  group('DebugScreen.resolveHermesUrl', () {
    test('defaults to the Hermes API server, not the OpenClaw gateway', () {
      final url = DebugScreen.resolveHermesUrl(null);
      expect(url, AppConfig.defaultHermesUrl);
      expect(url, contains(':8642'));
      expect(url, isNot(contains(':18789')));
    });

    test('uses the saved Hermes URL', () {
      expect(
        DebugScreen.resolveHermesUrl('https://hermes.example.com'),
        'https://hermes.example.com',
      );
    });

    test('restores the port on a saved loopback URL without one', () {
      expect(
        DebugScreen.resolveHermesUrl('http://127.0.0.1'),
        AppConfig.normalizeHermesUrl('http://127.0.0.1'),
      );
    });
  });
}
