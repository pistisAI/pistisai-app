import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pistisai/brand/brand_licence.dart';

void main() {
  // Issued 2026-11-09 by tool/issue_licence.py; expires 2027-12-31.
  const issued = '''
{
  "payload": {
    "brand": "iacle",
    "format": "iacle-whitelabel-1",
    "issued": "2026-11-09",
    "licensee": "IAClé",
    "plan": "whitelabel",
    "seats": 5,
    "expires": "2027-12-31"
  },
  "signature": "iR83ph36Px76ldK4L8SAMbnW77Km-yi7Q-FVkoPlo3ZSE31-3VYZReVnUcpwgmXvUhuiShZnJMtOFb-Zo08vDw",
  "signing_key_id": "iacle-whitelabel-2026"
}
''';

  group('BrandLicence', () {
    test('issued licence verifies and reports its fields', () async {
      final result = await BrandLicence.validateJson(
        issued,
        requestedBrand: 'iacle',
      );
      expect(result.status, LicenceStatus.valid);
      expect(result.isActive, isTrue);
      expect(result.licensee, 'IAClé');
      expect(result.plan, 'whitelabel');
      expect(result.expires, '2027-12-31');
      expect(result.seats, '5');
    });

    test('tampered payload fails signature verification', () async {
      final tampered = jsonDecode(issued) as Map<String, dynamic>;
      (tampered['payload'] as Map<String, dynamic>)['seats'] = 999;
      final result = await BrandLicence.validate(
        tampered,
        requestedBrand: 'iacle',
      );
      expect(result.status, LicenceStatus.badSignature);
      expect(result.isActive, isFalse);
    });

    test('wrong brand is rejected', () async {
      final result = await BrandLicence.validateJson(
        issued,
        requestedBrand: 'pistisai',
      );
      expect(result.status, LicenceStatus.wrongBrand);
    });

    test('expired licence is rejected', () async {
      // Re-signing is impossible without the private key, so a modified
      // expiry fails on signature first — which is the tamper evidence.
      final expired = jsonDecode(issued) as Map<String, dynamic>;
      (expired['payload'] as Map<String, dynamic>)['expires'] = '2020-01-01';
      final result = await BrandLicence.validate(expired);
      expect(result.status, LicenceStatus.badSignature);
    });

    test('garbage input is malformed, not a crash', () async {
      final result = await BrandLicence.validateJson('not json at all');
      expect(result.status, LicenceStatus.malformed);
    });

    test('missing payload/signature is malformed', () async {
      final result = await BrandLicence.validateJson('{"foo": 1}');
      expect(result.status, LicenceStatus.malformed);
    });

    test('isExpired boundary', () {
      expect(BrandLicence.isExpired('2020-01-01'), isTrue);
      expect(BrandLicence.isExpired('2999-01-01'), isFalse);
      expect(BrandLicence.isExpired('not-a-date'), isFalse);
    });

    test('displayStatus names the licensee for a valid licence', () async {
      final result = await BrandLicence.validateJson(
        issued,
        requestedBrand: 'iacle',
      );
      expect(result.displayStatus, contains('IAClé'));
      expect(result.displayStatus, contains('2027-12-31'));
    });

    test('licence file on disk round-trips', () async {
      final tmp = Directory.systemTemp.createTempSync('licence');
      final file = File('${tmp.path}/iacle.licence');
      addTearDown(() => tmp.deleteSync(recursive: true));
      file.writeAsStringSync(issued);
      final result = await BrandLicence.validateJson(
        file.readAsStringSync(),
        requestedBrand: 'iacle',
      );
      expect(result.status, LicenceStatus.valid);
    });
  });
}
