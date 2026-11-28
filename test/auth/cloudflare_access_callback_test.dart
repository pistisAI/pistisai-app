import 'package:flutter_test/flutter_test.dart';
import 'package:pistisai/auth/providers/cloudflare_access_auth_provider.dart';

/// Regression tests for issue #852: a fresh sign-in carries the Access JWT
/// in the callback URL, so token extraction must work without any stored
/// session or DI setup.
void main() {
  group('CloudflareAccessAuthProvider.tokenFromCallback', () {
    test('reads cf_jwt from a deep-link callback', () {
      expect(
        CloudflareAccessAuthProvider.tokenFromCallback(
          'pistisai://callback?cf_jwt=header.payload.signature',
        ),
        'header.payload.signature',
      );
    });

    test('reads the generic token alias from a web callback', () {
      expect(
        CloudflareAccessAuthProvider.tokenFromCallback(
          'https://app.example.com/callback?token=abc.def.ghi',
        ),
        'abc.def.ghi',
      );
    });

    test('prefers cf_jwt when both aliases are present', () {
      expect(
        CloudflareAccessAuthProvider.tokenFromCallback(
          'https://app.example.com/?cf_jwt=preferred&token=fallback',
        ),
        'preferred',
      );
    });

    test('returns null when the URL has no token', () {
      expect(
        CloudflareAccessAuthProvider.tokenFromCallback(
          'pistisai://callback?code=legacy',
        ),
        isNull,
      );
      expect(CloudflareAccessAuthProvider.tokenFromCallback(''), isNull);
    });

    test('storage key stays stable for stored sessions', () {
      expect(CloudflareAccessAuthProvider.tokenStorageKey, 'cf_access_jwt');
    });
  });
}
