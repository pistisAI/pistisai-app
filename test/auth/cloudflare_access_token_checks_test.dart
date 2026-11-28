import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:pistisai/auth/providers/cloudflare_access_auth_provider.dart';
import 'package:pistisai/auth/providers/cloudflare_access_token_checks.dart';
import 'package:pistisai/config/app_config.dart';

/// #852 follow-up (review of #983): callback tokens are checked before they
/// are stored, and a callback is tied to a sign-in started from this app.

String _b64(Object json) =>
    base64Url.encode(utf8.encode(jsonEncode(json))).replaceAll('=', '');

String jwt(Map<String, Object?> claims) =>
    '${_b64({'alg': 'RS256', 'typ': 'JWT'})}.${_b64(claims)}.signature';

class MemoryStore implements AccessSessionStore {
  final Map<String, String> values = {};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;

  @override
  Future<void> delete(String key) async => values.remove(key);
}

void main() {
  final now = DateTime.utc(2026, 11, 27, 12);
  final aud = AppConfig.cloudflareAccessAud;
  final team = AppConfig.cloudflareAccessTeamDomain;

  Map<String, Object?> goodClaims({String sub = 'user-a'}) => {
        'sub': sub,
        'email': '$sub@example.com',
        'aud': [aud],
        'iss': 'https://$team',
        'exp': now.add(const Duration(hours: 1)).millisecondsSinceEpoch ~/ 1000,
      };

  String callback(Map<String, Object?> claims, {String? state}) {
    final q = {'cf_jwt': jwt(claims), if (state != null) 'state': state};
    return Uri(scheme: 'pistisai', host: 'callback', queryParameters: q)
        .toString();
  }

  test('brand has an Access audience and team domain configured', () {
    expect(aud, isNotEmpty);
    expect(team, isNotEmpty);
  });

  group('checkAccessToken', () {
    AccessCallbackOutcome check(String token) =>
        checkAccessToken(token, audience: aud, teamDomain: team, now: now)
            .outcome;

    test('accepts a well-formed, unexpired token for this application', () {
      final result = checkAccessToken(jwt(goodClaims()),
          audience: aud, teamDomain: team, now: now);
      expect(result.outcome, AccessCallbackOutcome.accepted);
      expect(result.claims!.subject, 'user-a');
      expect(result.claims!.email, 'user-a@example.com');
    });

    test('accepts aud as a single string', () {
      expect(check(jwt({...goodClaims(), 'aud': aud})),
          AccessCallbackOutcome.accepted);
    });

    test('rejects tokens that are not three-part JWTs', () {
      expect(check('header.payload'), AccessCallbackOutcome.malformed);
      expect(check('a.b.c.d'), AccessCallbackOutcome.malformed);
      expect(check('not-a-jwt'), AccessCallbackOutcome.malformed);
      expect(check('x.!!!.y'), AccessCallbackOutcome.malformed);
      expect(check('${_b64({})}.${base64Url.encode(utf8.encode('[1]'))}.s'),
          AccessCallbackOutcome.malformed);
    });

    test('rejects a token without exp', () {
      expect(check(jwt({...goodClaims()}..remove('exp'))),
          AccessCallbackOutcome.expired);
    });

    test('rejects an expired token, allowing 60 s of skew', () {
      int at(Duration d) => now.add(d).millisecondsSinceEpoch ~/ 1000;
      expect(
          check(
              jwt({...goodClaims(), 'exp': at(const Duration(seconds: -30))})),
          AccessCallbackOutcome.accepted);
      expect(
          check(
              jwt({...goodClaims(), 'exp': at(const Duration(seconds: -61))})),
          AccessCallbackOutcome.expired);
      expect(check(jwt({...goodClaims(), 'exp': at(const Duration(days: -1))})),
          AccessCallbackOutcome.expired);
    });

    test('rejects a token for another Access application', () {
      expect(
          check(jwt({
            ...goodClaims(),
            'aud': ['other-aud']
          })),
          AccessCallbackOutcome.wrongAudience);
      expect(check(jwt({...goodClaims()}..remove('aud'))),
          AccessCallbackOutcome.wrongAudience);
    });

    test('rejects a token from another issuer', () {
      expect(
          check(jwt(
              {...goodClaims(), 'iss': 'https://evil.cloudflareaccess.com'})),
          AccessCallbackOutcome.wrongIssuer);
      expect(check(jwt({...goodClaims()}..remove('iss'))),
          AccessCallbackOutcome.wrongIssuer);
    });

    test('rejects everything when Access is not configured', () {
      expect(
          checkAccessToken(jwt(goodClaims()),
                  audience: '', teamDomain: '', now: now)
              .outcome,
          AccessCallbackOutcome.notConfigured);
    });
  });

  group('AccessPendingSignIn', () {
    test('state has at least 128 bits and differs per sign-in', () {
      final a = AccessPendingSignIn.start(now);
      final b = AccessPendingSignIn.start(now);
      expect(base64Url.decode(base64Url.normalize(a.state)).length,
          greaterThanOrEqualTo(16));
      expect(a.state, isNot(b.state));
    });

    test('expires after ten minutes and round-trips through storage', () {
      final p = AccessPendingSignIn.start(now);
      expect(p.isExpired(now.add(const Duration(minutes: 9))), isFalse);
      expect(p.isExpired(now.add(const Duration(minutes: 10))), isTrue);
      final back = AccessPendingSignIn.decode(p.encode())!;
      expect(back.state, p.state);
      expect(back.startedAt, p.startedAt);
      expect(AccessPendingSignIn.decode('garbage'), isNull);
    });
  });

  group('CloudflareAccessAuthProvider callbacks', () {
    late MemoryStore store;

    setUp(() {
      store = MemoryStore();
      CloudflareAccessAuthProvider.resetPendingSignInForTest();
    });

    Future<AccessCallbackOutcome> process(String url, {DateTime? at}) =>
        CloudflareAccessAuthProvider.processCallback(url,
            store: store, now: at ?? now);

    test('refuses a callback no sign-in was started for', () async {
      expect(await process(callback(goodClaims())),
          AccessCallbackOutcome.noPendingSignIn);
      expect(store.values, isEmpty);
    });

    test('refuses a forged or expired token even during a sign-in', () async {
      await CloudflareAccessAuthProvider.startPendingSignIn(
          store: store, now: now);
      expect(
          await process('pistisai://callback?cf_jwt=header.payload.signature'),
          AccessCallbackOutcome.malformed);
      expect(await process(callback({...goodClaims(), 'exp': 1})),
          AccessCallbackOutcome.expired);
      expect(
          store.values
              .containsKey(CloudflareAccessAuthProvider.tokenStorageKey),
          isFalse);
    });

    test('accepts a callback for a started sign-in and uses it once', () async {
      await CloudflareAccessAuthProvider.startPendingSignIn(
          store: store, now: now);
      expect(await process(callback(goodClaims())),
          AccessCallbackOutcome.accepted);
      expect(store.values[CloudflareAccessAuthProvider.tokenStorageKey],
          isNotNull);
      expect(
          store.values.containsKey(
              CloudflareAccessAuthProvider.pendingSignInStorageKey),
          isFalse);
      // A second account cannot ride on the consumed sign-in.
      expect(await process(callback(goodClaims(sub: 'attacker'))),
          AccessCallbackOutcome.differentAccount);
    });

    test('a pending sign-in in storage survives a cold start', () async {
      await CloudflareAccessAuthProvider.startPendingSignIn(
          store: store, now: now);
      CloudflareAccessAuthProvider.resetPendingSignInForTest();
      expect(
          await process(callback(goodClaims()),
              at: now.add(const Duration(minutes: 5))),
          AccessCallbackOutcome.accepted);
    });

    test('a sign-in started more than ten minutes ago is refused', () async {
      await CloudflareAccessAuthProvider.startPendingSignIn(
          store: store, now: now);
      expect(
          await process(callback(goodClaims()),
              at: now.add(const Duration(minutes: 11))),
          AccessCallbackOutcome.noPendingSignIn);
    });

    test('a callback state must match the started sign-in', () async {
      final pending = await CloudflareAccessAuthProvider.startPendingSignIn(
          store: store, now: now);
      expect(await process(callback(goodClaims(), state: 'wrong')),
          AccessCallbackOutcome.stateMismatch);
      // The rejected link did not cancel the user's sign-in.
      expect(await process(callback(goodClaims(), state: pending.state)),
          AccessCallbackOutcome.accepted);
    });

    test('never replaces a signed-in account from an unrequested link',
        () async {
      store.values[CloudflareAccessAuthProvider.tokenStorageKey] =
          jwt(goodClaims(sub: 'victim'));
      expect(await process(callback(goodClaims(sub: 'attacker'))),
          AccessCallbackOutcome.differentAccount);
      expect(store.values[CloudflareAccessAuthProvider.tokenStorageKey],
          jwt(goodClaims(sub: 'victim')));
      // The same account may refresh its token.
      expect(await process(callback(goodClaims(sub: 'victim'))),
          AccessCallbackOutcome.accepted);
    });

    test('a user-started sign-in may switch accounts', () async {
      store.values[CloudflareAccessAuthProvider.tokenStorageKey] =
          jwt(goodClaims(sub: 'old'));
      await CloudflareAccessAuthProvider.startPendingSignIn(
          store: store, now: now);
      expect(await process(callback(goodClaims(sub: 'new'))),
          AccessCallbackOutcome.accepted);
    });

    test('handleCallback reports the outcome and signs in only on accept',
        () async {
      final provider =
          CloudflareAccessAuthProvider(store: store, clock: () => now);
      expect(
          await provider.handleCallback(url: callback(goodClaims())), isFalse);
      expect(provider.currentUser, isNull);
      expect(
          provider.lastCallbackOutcome, AccessCallbackOutcome.noPendingSignIn);

      await CloudflareAccessAuthProvider.startPendingSignIn(
          store: store, now: now);
      expect(
          await provider.handleCallback(url: callback(goodClaims())), isTrue);
      expect(provider.currentUser!.id, 'user-a');
      expect(await provider.getAccessToken(), isNotNull);
    });

    test('initialize drops an expired stored token', () async {
      store.values[CloudflareAccessAuthProvider.tokenStorageKey] =
          jwt({...goodClaims(), 'exp': 1});
      final provider =
          CloudflareAccessAuthProvider(store: store, clock: () => now);
      await provider.initialize();
      expect(provider.currentUser, isNull);
      expect(await provider.getAccessToken(), isNull);
      expect(store.values, isEmpty);
    });

    test('persistTokenFromCallback refuses an unrequested token', () async {
      expect(
          await CloudflareAccessAuthProvider.persistTokenFromCallback(
              callback(goodClaims()),
              store: store,
              now: now),
          isFalse);
      expect(store.values, isEmpty);
    });
  });
}
