import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:pistisai/auth/auth_provider.dart';
import 'package:pistisai/auth/providers/cloudflare_access_token_checks.dart';
import 'package:pistisai/config/app_config.dart';
import 'package:pistisai/models/user_model.dart';

export 'package:pistisai/auth/providers/cloudflare_access_token_checks.dart'
    show AccessCallbackOutcome;

/// Key/value store for the Access session (secure storage in the app, a map
/// in tests).
abstract class AccessSessionStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

class _SecureAccessSessionStore implements AccessSessionStore {
  const _SecureAccessSessionStore();
  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}

/// Cloudflare Access is the only cloud identity path (free pistisai.app tunnel).
///
/// Local desktop use never calls this provider's network path: [initialize]
/// only reads a stored JWT from secure storage, and [login] opens the Access
/// challenge only when the user chooses device sync. The team domain and
/// audience come from the baked brand; `--dart-define` can override them.
/// Callbacks may carry the Access JWT as `token` or `cf_jwt`.
///
/// Before a callback token is stored it must be a three-part JWT that is not
/// expired and names the configured audience and team domain, and it must
/// belong to a sign-in the user started from this app in the last ten
/// minutes, unless it only refreshes the account already signed in (see
/// `cloudflare_access_token_checks.dart`). The signature is verified by the
/// backend, not here.
class CloudflareAccessAuthProvider extends AuthProvider {
  CloudflareAccessAuthProvider({
    AccessSessionStore? store,
    DateTime Function()? clock,
  })  : _store = store ?? const _SecureAccessSessionStore(),
        _clock = clock ?? DateTime.now;

  final AccessSessionStore _store;
  final DateTime Function() _clock;
  final StreamController<bool> _authStateController =
      StreamController<bool>.broadcast();

  UserModel? _currentUser;
  String? _accessToken;

  /// Storage key shared with the desktop deep-link handler in `main.dart`.
  static const String tokenStorageKey = 'cf_access_jwt';

  /// Storage key of the sign-in started from this app (see
  /// [AccessPendingSignIn]).
  static const String pendingSignInStorageKey = 'cf_access_pending_sign_in';

  /// The pending sign-in of this process; secure storage holds a copy so a
  /// cold-started instance can still match it.
  static AccessPendingSignIn? _pendingInMemory;

  AccessCallbackOutcome? _lastCallbackOutcome;

  /// Outcome of the last [handleCallback] call with a URL, for error text.
  AccessCallbackOutcome? get lastCallbackOutcome => _lastCallbackOutcome;

  bool get _configured =>
      AppConfig.cloudflareAccessTeamDomain.isNotEmpty &&
      AppConfig.cloudflareAccessAud.isNotEmpty;

  @override
  Stream<bool> get authStateChanges => _authStateController.stream;

  @override
  UserModel? get currentUser => _currentUser;

  @override
  Future<void> initialize() async {
    String? stored;
    try {
      stored = await _store.read(tokenStorageKey);
    } catch (e) {
      debugPrint('[CloudflareAccessAuthProvider] Failed to read session: $e');
    }
    if (stored == null || stored.isEmpty) {
      _accessToken = null;
      _currentUser = null;
      _authStateController.add(false);
      return;
    }
    final check = _check(stored, _clock());
    if (!check.isValid) {
      // Expired or not for this Access application: do not show the user as
      // signed in with a token the backend will refuse.
      debugPrint(
          '[CloudflareAccessAuthProvider] Stored session rejected: ${check.outcome.name}');
      _accessToken = null;
      _currentUser = null;
      try {
        await _store.delete(tokenStorageKey);
      } catch (_) {}
      _authStateController.add(false);
      return;
    }
    _accessToken = stored;
    _currentUser = _userFromClaims(check.claims!);
    _authStateController.add(true);
  }

  @override
  Future<void> login() async {
    if (!_configured) {
      return;
    }
    // Record that the user started a sign-in, so the callback that follows
    // can be told apart from a link another site opened.
    await startPendingSignIn(store: _store, now: _clock());
    final uri = Uri.parse(AppConfig.appUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Future<void> logout() async {
    _accessToken = null;
    _currentUser = null;
    _authStateController.add(false);
    _pendingInMemory = null;
    try {
      await _store.delete(tokenStorageKey);
      await _store.delete(pendingSignInStorageKey);
    } catch (e) {
      debugPrint('[CloudflareAccessAuthProvider] Failed to clear session: $e');
    }
  }

  @override
  Future<bool> handleCallback({String? url}) async {
    if (url == null || url.isEmpty) {
      return _accessToken != null;
    }
    final now = _clock();
    final outcome = await processCallback(url, store: _store, now: now);
    _lastCallbackOutcome = outcome;
    if (outcome != AccessCallbackOutcome.accepted) {
      debugPrint(
          '[CloudflareAccessAuthProvider] Callback rejected: ${outcome.name}');
      return false;
    }
    final token = tokenFromCallback(url)!;
    _accessToken = token;
    _currentUser = _userFromClaims(_check(token, now).claims!);
    _authStateController.add(true);
    return true;
  }

  @override
  Future<void> loginMockDeveloper() async {
    if (kReleaseMode) {
      return;
    }
    _currentUser = UserModel(
      id: '00000000-0000-0000-0000-000000000000',
      email: AppConfig.devModeUser,
      name: 'Dev User',
      nickname: 'dev',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    _authStateController.add(true);
  }

  @override
  Future<String?> getAccessToken() async {
    return _accessToken;
  }

  /// Extract an Access JWT from a callback URL.
  ///
  /// Shared with the desktop deep-link handler in `main.dart`, which receives
  /// `pistisai://callback?cf_jwt=...` as a command-line argument before DI is
  /// available. `cf_jwt` wins over the generic `token` alias.
  static String? tokenFromCallback(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) {
      return null;
    }
    return uri.queryParameters['cf_jwt'] ?? uri.queryParameters['token'];
  }

  /// Persist a JWT delivered through a desktop deep link so the next
  /// [initialize] call restores the session. Returns false when the callback
  /// is rejected (see [processCallback]) or secure storage is unavailable.
  static Future<bool> persistTokenFromCallback(
    String url, {
    AccessSessionStore? store,
    DateTime? now,
  }) async {
    final outcome = await processCallback(
      url,
      store: store ?? const _SecureAccessSessionStore(),
      now: now ?? DateTime.now(),
    );
    if (outcome != AccessCallbackOutcome.accepted) {
      debugPrint(
          '[CloudflareAccessAuthProvider] Deep-link callback rejected: ${outcome.name}');
      return false;
    }
    return true;
  }

  /// Record a sign-in started by the user, in memory and in [store].
  @visibleForTesting
  static Future<AccessPendingSignIn> startPendingSignIn({
    required AccessSessionStore store,
    required DateTime now,
  }) async {
    final pending = AccessPendingSignIn.start(now);
    _pendingInMemory = pending;
    try {
      await store.write(pendingSignInStorageKey, pending.encode());
    } catch (e) {
      debugPrint(
          '[CloudflareAccessAuthProvider] Failed to store pending sign-in: $e');
    }
    return pending;
  }

  /// Forget the in-memory pending sign-in (tests only).
  @visibleForTesting
  static void resetPendingSignInForTest() => _pendingInMemory = null;

  /// Check a callback URL and, when accepted, store its token and consume the
  /// pending sign-in. Nothing is written for a rejected callback, and a
  /// rejected callback does not consume the pending sign-in (so a stray link
  /// cannot cancel the user's own sign-in).
  static Future<AccessCallbackOutcome> processCallback(
    String url, {
    required AccessSessionStore store,
    required DateTime now,
  }) async {
    final token = tokenFromCallback(url);
    if (token == null || token.isEmpty) {
      return AccessCallbackOutcome.noToken;
    }
    final check = _check(token, now);
    if (!check.isValid) {
      return check.outcome;
    }

    var pending = _pendingInMemory;
    if (pending == null) {
      try {
        pending = AccessPendingSignIn.decode(
            await store.read(pendingSignInStorageKey));
      } catch (_) {
        pending = null;
      }
    }

    String? existingSubject;
    try {
      final existing = await store.read(tokenStorageKey);
      if (existing != null && existing.isNotEmpty) {
        final sub = decodeJwtPayload(existing)?['sub'];
        existingSubject = sub is String ? sub : null;
      }
    } catch (_) {
      existingSubject = null;
    }

    final outcome = decideAccessCallback(
      token: check,
      callbackState: Uri.tryParse(url)?.queryParameters['state'],
      pending: pending,
      existingSubject: existingSubject,
      now: now,
    );
    if (outcome != AccessCallbackOutcome.accepted) {
      return outcome;
    }

    try {
      await store.write(tokenStorageKey, token);
    } catch (e) {
      debugPrint(
          '[CloudflareAccessAuthProvider] Failed to persist session: $e');
      return AccessCallbackOutcome.storageFailed;
    }
    // A started sign-in is used once.
    _pendingInMemory = null;
    try {
      await store.delete(pendingSignInStorageKey);
    } catch (_) {}
    return AccessCallbackOutcome.accepted;
  }

  static AccessTokenCheck _check(String token, DateTime now) =>
      checkAccessToken(
        token,
        audience: AppConfig.cloudflareAccessAud,
        teamDomain: AppConfig.cloudflareAccessTeamDomain,
        now: now,
      );

  UserModel _userFromClaims(AccessTokenClaims claims) {
    final now = _clock();
    return UserModel(
      id: claims.subject,
      email: claims.email,
      name: claims.name,
      createdAt: now,
      updatedAt: now,
    );
  }
}
