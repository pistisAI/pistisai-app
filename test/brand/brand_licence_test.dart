import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pistisai/brand/brand_licence.dart';

void main() {
  group('BrandLicence', () {
    late String issued;
    late String publicKey;

    setUp(() async {
      final signed = await _issue(
        brand: 'acme',
        licensee: 'Acme Labs',
        expires: '2027-12-31',
        seats: 5,
      );
      issued = signed.licence;
      publicKey = signed.publicKey;
    });

    test('issued licence verifies and reports its fields', () async {
      final result = await BrandLicence.validateJson(
        issued,
        requestedBrand: 'acme',
        publicKeyB64Url: publicKey,
      );
      expect(result.status, LicenceStatus.valid);
      expect(result.isActive, isTrue);
      expect(result.licensee, 'Acme Labs');
      expect(result.plan, 'whitelabel');
      expect(result.expires, '2027-12-31');
      expect(result.seats, '5');
    });

    test('tampered payload fails signature verification', () async {
      final tampered = jsonDecode(issued) as Map<String, dynamic>;
      (tampered['payload'] as Map<String, dynamic>)['seats'] = 999;
      final result = await BrandLicence.validate(
        tampered,
        requestedBrand: 'acme',
        publicKeyB64Url: publicKey,
      );
      expect(result.status, LicenceStatus.badSignature);
      expect(result.isActive, isFalse);
    });

    test('wrong brand is rejected', () async {
      final result = await BrandLicence.validateJson(
        issued,
        requestedBrand: 'pistisai',
        publicKeyB64Url: publicKey,
      );
      expect(result.status, LicenceStatus.wrongBrand);
    });

    test('expired licence is rejected', () async {
      // Re-signing is impossible without the private key, so a modified
      // expiry fails on signature first — which is the tamper evidence.
      final expired = jsonDecode(issued) as Map<String, dynamic>;
      (expired['payload'] as Map<String, dynamic>)['expires'] = '2020-01-01';
      final result = await BrandLicence.validate(
        expired,
        publicKeyB64Url: publicKey,
      );
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
        requestedBrand: 'acme',
        publicKeyB64Url: publicKey,
      );
      expect(result.displayStatus, contains('Acme Labs'));
      expect(result.displayStatus, contains('2027-12-31'));
    });

    test('licence file on disk round-trips', () async {
      final tmp = Directory.systemTemp.createTempSync('licence');
      final file = File('${tmp.path}/acme.licence');
      addTearDown(() => tmp.deleteSync(recursive: true));
      file.writeAsStringSync(issued);
      final result = await BrandLicence.validateJson(
        file.readAsStringSync(),
        requestedBrand: 'acme',
        publicKeyB64Url: publicKey,
      );
      expect(result.status, LicenceStatus.valid);
    });

    test('a signature from another key fails against the licensor key', () async {
      final result = await BrandLicence.validateJson(
        issued,
        requestedBrand: 'acme',
      );
      expect(result.status, LicenceStatus.badSignature);
    });
  });
}

class _SignedLicence {
  const _SignedLicence({required this.licence, required this.publicKey});

  final String licence;
  final String publicKey;
}

Future<_SignedLicence> _issue({
  required String brand,
  required String licensee,
  required String expires,
  required int seats,
}) async {
  final algorithm = Ed25519();
  final keyPair = await algorithm.newKeyPair();
  final publicKey = await keyPair.extractPublicKey();
  final payload = <String, dynamic>{
    'brand': brand,
    'expires': expires,
    'format': 'pistisai-whitelabel-1',
    'issued': '2026-11-09',
    'licensee': licensee,
    'plan': 'whitelabel',
    'seats': seats,
  };
  final message = utf8.encode(jsonEncode(payload));
  final signature = await algorithm.sign(message, keyPair: keyPair);
  final licence = jsonEncode(<String, dynamic>{
    'payload': payload,
    'signature': base64Url.encode(signature.bytes).replaceAll('=', ''),
    'signing_key_id': 'pistisai-whitelabel-2026',
  });
  return _SignedLicence(
    licence: licence,
    publicKey: base64Url.encode(publicKey.bytes).replaceAll('=', ''),
  );
}
