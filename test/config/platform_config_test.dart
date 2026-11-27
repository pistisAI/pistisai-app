// Checks committed native platform config against the product guardrails
// in AGENTS.md (issue #1016).
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pistisai/brand/brand.dart';

import '../../tool/brand_emit.dart';

String _read(String path) => File(path).readAsStringSync();

void main() {
  const manifestPath = 'android/app/src/main/AndroidManifest.xml';
  const rulesPath = 'android/app/src/main/res/xml/data_extraction_rules.xml';
  const installerPath = 'windows/installer/Pistisai.iss';

  group('Android backup opt-out', () {
    test('manifest disables Auto Backup and device transfer', () {
      final manifest = _read(manifestPath);
      expect(manifest, contains('android:allowBackup="false"'));
      expect(manifest, contains('android:fullBackupContent="false"'));
      expect(
        manifest,
        contains('android:dataExtractionRules="@xml/data_extraction_rules"'),
      );
    });

    test('data extraction rules exclude every domain', () {
      final file = File(rulesPath);
      expect(file.existsSync(), isTrue, reason: '$rulesPath missing');
      final rules = file.readAsStringSync();
      for (final section in ['cloud-backup', 'device-transfer']) {
        final match = RegExp(
          '<$section>(.*?)</$section>',
          dotAll: true,
        ).firstMatch(rules);
        expect(match, isNotNull, reason: '$section section missing');
        final body = match!.group(1)!;
        expect(body, isNot(contains('<include')));
        for (final domain in [
          'root',
          'file',
          'database',
          'sharedpref',
          'external',
        ]) {
          expect(
            body,
            contains('<exclude domain="$domain" path="."'),
            reason: '$section must exclude $domain',
          );
        }
      }
    });
  });

  group('macOS network entitlements', () {
    for (final name in ['Release', 'DebugProfile']) {
      test('$name allows client and server sockets', () {
        final plist = _read('macos/Runner/$name.entitlements');
        for (final key in [
          'com.apple.security.network.client',
          'com.apple.security.network.server',
        ]) {
          expect(
            RegExp('<key>$key</key>\\s*<true/>').hasMatch(plist),
            isTrue,
            reason: '$name.entitlements must set $key',
          );
        }
      });
    }
  });

  group('callback scheme', () {
    final scheme = Brand.current.urlScheme;

    test('brand scheme is lowercase', () {
      expect(scheme, scheme.toLowerCase());
    });

    test('Android intent filter uses the brand scheme', () {
      final schemes = RegExp(r'android:scheme="([^"]+)"')
          .allMatches(_read(manifestPath))
          .map((m) => m.group(1)!)
          .toList();
      expect(schemes, [scheme]);
      expect(
        Brand.current.isCallbackUrl('${schemes.single}://callback'),
        isTrue,
      );
    });

    test('Android build default scheme is the brand scheme', () {
      expect(
        _read('android/app/build.gradle'),
        contains("getProperty('auth0_scheme', '$scheme')"),
      );
    });

    test('Windows installer registers the brand scheme', () {
      final protocol = RegExp(
        r'#define MyAppProtocol "([^"]+)"',
      ).firstMatch(_read(installerPath))!.group(1)!;
      expect(protocol, scheme);
      expect(Brand.current.isCallbackUrl('$protocol://callback'), isTrue);
    });

    test('brand bake writes the scheme into native files', () {
      final manifest = applyAndroidManifest(
        _read(manifestPath),
        Brand.current,
      );
      expect(manifest, contains('android:scheme="$scheme"'));
      final installer = applyInstaller(_read(installerPath), Brand.current);
      expect(installer, contains('#define MyAppProtocol "$scheme"'));
    });
  });
}
