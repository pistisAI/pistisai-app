import 'package:pistisai/config/app_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('paired-device transport remains enabled', () {
    expect(AppConfig.skipDeviceIdentity, isFalse);
  });

  group('normalizeHermesUrl', () {
    test('adds the default port to loopback URLs that stripped it', () {
      expect(
        AppConfig.normalizeHermesUrl('http://127.0.0.1'),
        'http://127.0.0.1:8642',
      );
      expect(
        AppConfig.normalizeHermesUrl('http://localhost'),
        'http://localhost:8642',
      );
    });

    test('keeps an explicit Hermes port and remote HTTPS URLs', () {
      expect(
        AppConfig.normalizeHermesUrl('http://127.0.0.1:8642'),
        'http://127.0.0.1:8642',
      );
      expect(
        AppConfig.normalizeHermesUrl('https://app.pistisai.app/hermes'),
        'https://app.pistisai.app/hermes',
      );
    });

    test('empty input falls back to the default Hermes URL', () {
      expect(AppConfig.normalizeHermesUrl(''), AppConfig.defaultHermesUrl);
      expect(AppConfig.normalizeHermesUrl('   '), AppConfig.defaultHermesUrl);
    });
  });
}
