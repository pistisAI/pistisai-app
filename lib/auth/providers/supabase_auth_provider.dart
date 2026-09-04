import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:rxdart/rxdart.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../config/app_config.dart';
import '../../models/user_model.dart';
import '../auth_provider.dart';

/// Supabase-backed [AuthProvider] (replaces the Auth0 implementation, issue #219).
///
/// Session persistence, silent refresh, and (on web) detecting the OAuth code in
/// the return URL are handled by `supabase_flutter`. This class adapts the SDK's
/// session lifecycle to the app's provider-agnostic [AuthProvider] contract, so
/// `AuthService` and its many consumers need no changes.
class SupabaseAuthProvider implements AuthProvider {
  /// Deep-link target for native/desktop OAuth returns. Must be present in the
  /// Supabase project's redirect allow list.
  static const String _nativeRedirect = 'pistisai://callback';

  final BehaviorSubject<bool> _authSubject = BehaviorSubject.seeded(false);
  StreamSubscription<AuthState>? _authSubscription;
  UserModel? _currentUser;

  SupabaseClient get _client => Supabase.instance.client;

  @override
  Stream<bool> get authStateChanges => _authSubject.stream;

  @override
  UserModel? get currentUser => _currentUser;

  @override
  Future<void> initialize() async {
    // Dev-mode auto-login parity with the previous provider: skip the network.
    if (AppConfig.enableDevMode && !kIsWeb) {
      debugPrint('[SupabaseAuth] Dev Mode enabled, simulating login...');
      _currentUser = _devUser();
      _authSubject.add(true);
      return;
    }

    _authSubscription ??= _client.auth.onAuthStateChange.listen((state) {
      _applySession(state.session);
    }, onError: (Object e) {
      debugPrint('[SupabaseAuth] auth state stream error: $e');
    });

    // Reflect any session restored from storage by supabase_flutter.
    _applySession(_client.auth.currentSession);

    // On web, exchange an OAuth code present in the return URL, if any.
    if (kIsWeb) {
      unawaited(handleCallback());
    }
  }

  @override
  Future<bool> handleCallback({String? url}) async {
    try {
      final uri = url != null ? Uri.parse(url) : Uri.base;
      final hasAuthParams = uri.queryParameters.containsKey('code') ||
          uri.queryParameters.containsKey('error') ||
          uri.fragment.contains('access_token');

      if (!hasAuthParams) {
        return _client.auth.currentSession != null;
      }

      final response = await _client.auth.getSessionFromUrl(uri);
      _applySession(response.session);
      return _currentUser != null;
    } catch (e) {
      debugPrint('[SupabaseAuth] handleCallback error: $e');
      return _client.auth.currentSession != null;
    }
  }

  @override
  Future<void> login() async {
    try {
      await _client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: kIsWeb ? null : _nativeRedirect,
        authScreenLaunchMode: kIsWeb
            ? LaunchMode.platformDefault
            : LaunchMode.externalApplication,
      );
      // Web performs a full-page redirect; native returns via the deep link,
      // which drives `handleCallback` and the auth-state stream.
    } catch (e) {
      debugPrint('[SupabaseAuth] login error: $e');
      rethrow;
    }
  }

  @override
  Future<void> logout() async {
    try {
      await _client.auth.signOut();
    } catch (e) {
      debugPrint('[SupabaseAuth] logout error: $e');
    } finally {
      _currentUser = null;
      _authSubject.add(false);
    }
  }

  @override
  Future<String?> getAccessToken() async {
    final session = _client.auth.currentSession;
    if (session == null) return null;
    if (!session.isExpired) return session.accessToken;

    try {
      final refreshed = await _client.auth.refreshSession();
      return refreshed.session?.accessToken;
    } catch (e) {
      debugPrint('[SupabaseAuth] token refresh error: $e');
      return null;
    }
  }

  @override
  Future<void> loginMockDeveloper() async {
    if (kReleaseMode) return;
    _currentUser = _devUser();
    _authSubject.add(true);
  }

  void _applySession(Session? session) {
    if (session != null) {
      _currentUser = _userFromSupabase(session.user);
      _authSubject.add(true);
    } else {
      _currentUser = null;
      _authSubject.add(false);
    }
  }

  UserModel _userFromSupabase(User user) {
    final metadata = user.userMetadata ?? const <String, dynamic>{};
    String? asString(String key) => metadata[key] as String?;

    return UserModel(
      id: user.id,
      email: user.email ?? asString('email') ?? '',
      name: asString('full_name') ?? asString('name'),
      picture: asString('avatar_url') ?? asString('picture'),
      nickname: asString('preferred_username') ?? asString('user_name'),
      createdAt: DateTime.tryParse(user.createdAt) ?? DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  UserModel _devUser() => UserModel(
        id: 'google-oauth2|102509433531341542550',
        email: 'dev@pistisai.app',
        name: 'Christopher (Dev)',
        nickname: 'rightguy',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

  void dispose() {
    _authSubscription?.cancel();
    _authSubject.close();
  }
}
