import 'dart:convert';
import 'dart:math';

/// Client-side checks on a Cloudflare Access JWT and on the sign-in that
/// produced it (#852).
///
/// The app cannot verify the token signature: that needs the team's JWKS and
/// a network call, so the backend stays the authority and verifies every
/// request. These checks only stop the app from storing, or showing as
/// signed in, a token that is malformed, expired, issued for another Access
/// application, or delivered by a link the user did not ask for.

/// Why a callback or a stored token was accepted or rejected.
enum AccessCallbackOutcome {
  accepted,

  /// The URL has no `cf_jwt` / `token` parameter.
  noToken,

  /// Not a three-part JWT, or the payload is not a JSON object.
  malformed,

  /// No `exp` claim, or `exp` is in the past (beyond the allowed skew).
  expired,

  /// `aud` does not contain the configured Access audience.
  wrongAudience,

  /// `iss` is not the configured Access team domain.
  wrongIssuer,

  /// The app has no Access audience / team domain configured.
  notConfigured,

  /// The callback carries a `state` that does not match the pending sign-in.
  stateMismatch,

  /// No sign-in was started from this app in the last
  /// [AccessPendingSignIn.lifetime], and no session exists for this account.
  noPendingSignIn,

  /// A different account is already signed in and the user did not start a
  /// new sign-in: the existing session is kept.
  differentAccount,

  /// Secure storage could not be written.
  storageFailed,
}

/// The claims the app reads from an Access JWT.
class AccessTokenClaims {
  const AccessTokenClaims({
    required this.subject,
    required this.email,
    required this.name,
    required this.expiresAt,
  });

  final String subject;
  final String email;
  final String? name;
  final DateTime expiresAt;
}

/// Result of [checkAccessToken].
class AccessTokenCheck {
  const AccessTokenCheck._(this.outcome, this.claims);

  final AccessCallbackOutcome outcome;
  final AccessTokenClaims? claims;

  bool get isValid => outcome == AccessCallbackOutcome.accepted;
}

/// Clock skew allowed on `exp`.
const Duration accessTokenClockSkew = Duration(seconds: 60);

/// Decode the payload of a three-part JWT, or return null.
Map<String, dynamic>? decodeJwtPayload(String token) {
  final parts = token.split('.');
  if (parts.length != 3 || parts.any((p) => p.isEmpty)) {
    return null;
  }
  try {
    final decoded = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))));
    return decoded is Map<String, dynamic> ? decoded : null;
  } catch (_) {
    return null;
  }
}

String _normalizeHost(String value) {
  var v = value.trim().toLowerCase();
  final scheme = v.indexOf('://');
  if (scheme >= 0) {
    v = v.substring(scheme + 3);
  }
  while (v.endsWith('/')) {
    v = v.substring(0, v.length - 1);
  }
  return v;
}

/// Check structure, `exp`, `aud` and `iss` of an Access JWT.
///
/// [audience] and [teamDomain] are the configured Access application audience
/// and team host (`AppConfig.cloudflareAccessAud` /
/// `AppConfig.cloudflareAccessTeamDomain`). The signature is not checked.
AccessTokenCheck checkAccessToken(
  String token, {
  required String audience,
  required String teamDomain,
  required DateTime now,
  Duration skew = accessTokenClockSkew,
}) {
  if (audience.isEmpty || teamDomain.isEmpty) {
    return const AccessTokenCheck._(AccessCallbackOutcome.notConfigured, null);
  }
  final claims = decodeJwtPayload(token);
  if (claims == null) {
    return const AccessTokenCheck._(AccessCallbackOutcome.malformed, null);
  }

  final exp = claims['exp'];
  if (exp is! num) {
    return const AccessTokenCheck._(AccessCallbackOutcome.expired, null);
  }
  final expiresAt =
      DateTime.fromMillisecondsSinceEpoch((exp * 1000).round(), isUtc: true);
  if (!expiresAt.add(skew).isAfter(now.toUtc())) {
    return const AccessTokenCheck._(AccessCallbackOutcome.expired, null);
  }

  final aud = claims['aud'];
  final audiences = aud is String
      ? <String>[aud]
      : aud is List
          ? aud.whereType<String>().toList()
          : const <String>[];
  if (!audiences.contains(audience)) {
    return const AccessTokenCheck._(AccessCallbackOutcome.wrongAudience, null);
  }

  final iss = claims['iss'];
  if (iss is! String || _normalizeHost(iss) != _normalizeHost(teamDomain)) {
    return const AccessTokenCheck._(AccessCallbackOutcome.wrongIssuer, null);
  }

  final sub = claims['sub'];
  if (sub is! String || sub.isEmpty) {
    return const AccessTokenCheck._(AccessCallbackOutcome.malformed, null);
  }

  return AccessTokenCheck._(
    AccessCallbackOutcome.accepted,
    AccessTokenClaims(
      subject: sub,
      email: claims['email'] as String? ?? '',
      name: claims['name'] as String?,
      expiresAt: expiresAt,
    ),
  );
}

/// A sign-in the user started from this app (by pressing sign in).
///
/// It is kept in memory and in secure storage for [lifetime] and is used
/// once. A deep-link callback that would create or replace a session is
/// accepted only while one is pending.
class AccessPendingSignIn {
  const AccessPendingSignIn({required this.state, required this.startedAt});

  /// How long a started sign-in stays valid.
  static const Duration lifetime = Duration(minutes: 10);

  /// Random value, 256 bits, base64url.
  final String state;
  final DateTime startedAt;

  factory AccessPendingSignIn.start(DateTime now, {Random? random}) {
    final rng = random ?? Random.secure();
    final bytes = List<int>.generate(32, (_) => rng.nextInt(256));
    return AccessPendingSignIn(
      state: base64Url.encode(bytes).replaceAll('=', ''),
      startedAt: now.toUtc(),
    );
  }

  bool isExpired(DateTime now) => !startedAt.add(lifetime).isAfter(now.toUtc());

  String encode() => jsonEncode({
        'state': state,
        'started': startedAt.millisecondsSinceEpoch,
      });

  static AccessPendingSignIn? decode(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      final map = jsonDecode(raw);
      if (map is! Map<String, dynamic>) return null;
      final state = map['state'];
      final started = map['started'];
      if (state is! String || state.isEmpty || started is! int) return null;
      return AccessPendingSignIn(
        state: state,
        startedAt: DateTime.fromMillisecondsSinceEpoch(started, isUtc: true),
      );
    } catch (_) {
      return null;
    }
  }
}

/// Decide whether a callback token may become the stored session.
///
/// * [callbackState] — the `state` parameter of the callback, if any. When
///   present it must equal the pending sign-in's state.
/// * [pending] — the sign-in started from this app, or null. Expired entries
///   count as none.
/// * [existingSubject] — `sub` of the session already stored, or null.
///
/// A session is created or replaced only while a sign-in is pending. Without
/// one, the callback may only refresh the token of the account already
/// signed in; any other account is refused so a link opened by another site
/// cannot switch the user into a different account.
AccessCallbackOutcome decideAccessCallback({
  required AccessTokenCheck token,
  required String? callbackState,
  required AccessPendingSignIn? pending,
  required String? existingSubject,
  required DateTime now,
}) {
  if (!token.isValid) {
    return token.outcome;
  }
  final livePending =
      pending != null && !pending.isExpired(now) ? pending : null;
  if (callbackState != null &&
      (livePending == null || callbackState != livePending.state)) {
    return AccessCallbackOutcome.stateMismatch;
  }
  if (livePending != null) {
    return AccessCallbackOutcome.accepted;
  }
  if (existingSubject != null && existingSubject.isNotEmpty) {
    return existingSubject == token.claims!.subject
        ? AccessCallbackOutcome.accepted
        : AccessCallbackOutcome.differentAccount;
  }
  return AccessCallbackOutcome.noPendingSignIn;
}
