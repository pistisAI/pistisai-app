import 'package:flutter_test/flutter_test.dart';
import 'package:pistisai/config/router.dart';
import 'package:pistisai/config/router_redirect.dart';

/// Regression tests for issue #852: Access JWT callbacks must reach the
/// callback screen, and the offline control must not loop back to login.
void main() {
  group('hasCallbackParameters', () {
    test('detects Cloudflare Access JWT params', () {
      expect(
        hasCallbackParameters(
          Uri.parse('https://app.example.com/?cf_jwt=header.payload.sig'),
        ),
        isTrue,
      );
      expect(
        hasCallbackParameters(
          Uri.parse('https://app.example.com/?token=header.payload.sig'),
        ),
        isTrue,
      );
    });

    test('still detects legacy OAuth params', () {
      for (final param in ['code', 'state', 'error', 'error_description']) {
        expect(
          hasCallbackParameters(Uri.parse('https://app.example.com/?$param=x')),
          isTrue,
          reason: '$param must be forwarded to /callback',
        );
      }
    });

    test('ignores unrelated query params', () {
      expect(
        hasCallbackParameters(Uri.parse('https://app.example.com/?foo=bar')),
        isFalse,
      );
      expect(hasCallbackParameters(Uri.parse('https://app.example.com/')),
          isFalse);
    });
  });

  group('localModeDestination', () {
    test('web has no local-only destination so callers hide the button', () {
      expect(
        localModeDestination(isWeb: true, isMobile: false),
        isNull,
      );
      expect(
        localModeDestination(isWeb: true, isMobile: true),
        isNull,
      );
    });

    test('mobile in cloud mode goes to the connection screen', () {
      expect(
        localModeDestination(isWeb: false, isMobile: true),
        AppRoutePaths.connect,
      );
    });

    test('desktop continues to the app shell', () {
      expect(
        localModeDestination(isWeb: false, isMobile: false),
        AppRoutePaths.root,
      );
    });
  });
}
