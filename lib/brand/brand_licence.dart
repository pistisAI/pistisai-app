import 'dart:convert';

import 'package:cryptography/cryptography.dart';

/// Verification result for a whitelabel licence.
enum LicenceStatus {
  /// No licence supplied — only the upstream brand may be baked.
  absent,

  /// Licence present, signature valid, not expired.
  valid,

  /// Licence file could not be parsed.
  malformed,

  /// Signature does not match the payload — tampered or wrong key.
  badSignature,

  /// Licence is past its expiry date.
  expired,

  /// Licence is for a different brand than the one requested.
  wrongBrand,
}

/// Outcome of validating a whitelabel licence.
class LicenceResult {
  const LicenceResult({
    required this.status,
    this.licensee,
    this.plan,
    this.expires,
    this.seats,
    this.issued,
    this.detail,
  });

  final LicenceStatus status;
  final String? licensee;
  final String? plan;
  final String? expires;
  final String? seats;
  final String? issued;
  final String? detail;

  bool get isActive => status == LicenceStatus.valid;

  String get displayStatus {
    switch (status) {
      case LicenceStatus.valid:
        return 'Licensed to $licensee ($plan, expires $expires)';
      case LicenceStatus.absent:
        return 'No whitelabel licence';
      case LicenceStatus.malformed:
        return 'Licence file unreadable';
      case LicenceStatus.badSignature:
        return 'Licence signature invalid — not issued by the licensor';
      case LicenceStatus.expired:
        return 'Licence expired on $expires';
      case LicenceStatus.wrongBrand:
        return 'Licence is for a different brand';
    }
  }
}

/// Verifies whitelabel licences.
///
/// A licence is a JSON document with a canonical payload and an Ed25519
/// signature. The public key is embedded here; the private key stays with the
/// licensor and never enters the repository. Verification is offline — no
/// server call, no network.
///
/// Issued by `tool/issue_licence.py` (held with the private key).
class BrandLicence {
  const BrandLicence._();

  /// Ed25519 public key (base64url, unpadded) for the whitelabel key.
  /// Generated 2026-11-09; the private key is held by Christopher only.
  static const String _publicKeyB64Url =
      'cgP0caXDMmCdvconV2_X74UrlkJiyAlZAD6k2Bn3Auo';

  static final Ed25519 _ed25519 = Ed25519();

  /// Canonical serialization — must match tool/issue_licence.py exactly.
  static List<int> _canonicalPayload(Map<String, dynamic> payload) {
    final sorted = <String, dynamic>{};
    final keys = payload.keys.toList()..sort();
    for (final k in keys) {
      sorted[k] = payload[k];
    }
    return utf8.encode(jsonEncode(sorted));
  }

  /// Base64url decode, tolerant of missing padding.
  static List<int>? _b64UrlDecode(String input) {
    var s = input.trim();
    final pad = s.length % 4;
    if (pad != 0) s += '=' * (4 - pad);
    final normalized = s.replaceAll('-', '+').replaceAll('_', '/');
    try {
      return base64.decode(normalized);
    } catch (_) {
      return null;
    }
  }

  /// Verify an Ed25519 signature over [message] with the embedded public key.
  static Future<bool> _verifyEd25519(
    List<int> message,
    List<int> signature,
  ) async {
    final pubBytes = _b64UrlDecode(_publicKeyB64Url);
    if (pubBytes == null) return false;
    try {
      return await _ed25519.verify(
        message,
        signature: Signature(
          signature,
          publicKey: SimplePublicKey(pubBytes, type: KeyPairType.ed25519),
        ),
      );
    } catch (_) {
      return false;
    }
  }

  /// Validate a decoded licence document against the requested brand.
  static Future<LicenceResult> validate(
    Map<String, dynamic> licence, {
    String? requestedBrand,
  }) async {
    final payload = licence['payload'];
    final signature = licence['signature'];

    if (payload is! Map<String, dynamic> || signature is! String) {
      return const LicenceResult(
        status: LicenceStatus.malformed,
        detail: 'Missing payload or signature',
      );
    }

    final message = _canonicalPayload(payload);
    final sigBytes = _b64UrlDecode(signature);
    final ok = sigBytes != null && await _verifyEd25519(message, sigBytes);
    if (!ok) {
      return const LicenceResult(
        status: LicenceStatus.badSignature,
        detail: 'Signature verification failed',
      );
    }

    final brand = payload['brand'] as String?;
    if (requestedBrand != null && brand != requestedBrand) {
      return LicenceResult(
        status: LicenceStatus.wrongBrand,
        licensee: payload['licensee'] as String?,
        detail: 'Licence brand "$brand" != requested "$requestedBrand"',
      );
    }

    final expires = payload['expires'] as String?;
    if (expires != null && isExpired(expires)) {
      return LicenceResult(
        status: LicenceStatus.expired,
        licensee: payload['licensee'] as String?,
        plan: payload['plan'] as String?,
        expires: expires,
      );
    }

    return LicenceResult(
      status: LicenceStatus.valid,
      licensee: payload['licensee'] as String?,
      plan: payload['plan'] as String?,
      expires: expires,
      seats: payload['seats']?.toString(),
      issued: payload['issued'] as String?,
    );
  }

  /// Parse and validate a licence from a JSON string.
  static Future<LicenceResult> validateJson(
    String source, {
    String? requestedBrand,
  }) async {
    try {
      final decoded = jsonDecode(source);
      if (decoded is! Map<String, dynamic>) {
        return const LicenceResult(status: LicenceStatus.malformed);
      }
      return await validate(decoded, requestedBrand: requestedBrand);
    } catch (e) {
      return LicenceResult(
        status: LicenceStatus.malformed,
        detail: e.toString(),
      );
    }
  }

  /// Whether an ISO date (YYYY-MM-DD) is in the past.
  static bool isExpired(String isoDate) {
    final expiry = DateTime.tryParse(isoDate);
    if (expiry == null) return false;
    final today = DateTime.now().toUtc();
    final todayDate = DateTime.utc(today.year, today.month, today.day);
    return todayDate.isAfter(expiry);
  }
}
