import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:pistisai/auth/auth_provider.dart';
import 'package:pistisai/config/app_config.dart';
import 'package:pistisai/models/user_model.dart';

/// Supabase Auth provider for web and cloud-enabled desktop builds.
class SupabaseAuthProvider extends AuthProvider {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  final StreamController<bool> _authStateController =
      StreamController<bool>.broadcast();

  UserModel? _currentUser;
  StreamSubscription<AuthState>? _authSubscription;

  @override
  Stream<bool> get authStateChanges => _authStateController.stream;

  @override
  UserModel? get currentUser => _currentUser;

  @override
  Future<void> initialize() async {
    await _authSubscription?.cancel();
    _authSubscription =
        Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      final session = data.session;
      if (session != null) {
        _currentUser = _mapSupabaseUser(session.user);
        _authStateController.add(true);
        unawaited(_persistSession(session));
      } else {
        _currentUser = null;
        _authStateController.add(false);
        unawaited(_clearPersistedSession());
      }
    });

    final session = Supabase.instance.client.auth.currentSession;
    if (session != null) {
      _currentUser = _mapSupabaseUser(session.user);
      _authStateController.add(true);
    } else {
      _authStateController.add(false);
    }
  }

  @override
  Future<void> login() async {
    await Supabase.instance.client.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: _redirectUri,
    );
  }

  @override
  Future<void> logout() async {
    await Supabase.instance.client.auth.signOut();
    _currentUser = null;
    _authStateController.add(false);
    await _clearPersistedSession();
  }

  @override
  Future<bool> handleCallback({String? url}) async {
    if (url == null || url.isEmpty) {
      return Supabase.instance.client.auth.currentSession != null;
    }

    try {
      await Supabase.instance.client.auth.getSessionFromUrl(Uri.parse(url));
      final session = Supabase.instance.client.auth.currentSession;
      if (session != null) {
        _currentUser = _mapSupabaseUser(session.user);
        _authStateController.add(true);
        await _persistSession(session);
        return true;
      }
    } catch (e) {
      debugPrint('[SupabaseAuthProvider] Callback handling failed: $e');
    }
    return false;
  }

  @override
  Future<void> loginMockDeveloper() async {
    if (kReleaseMode) {
      return;
    }

    _currentUser = UserModel(
      id: '00000000-0000-0000-0000-000000000000',
      email: 'dev@pistisai.app',
      name: 'Christopher (Dev)',
      nickname: 'rightguy',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    _authStateController.add(true);
  }

  @override
  Future<String?> getAccessToken() async {
    return Supabase.instance.client.auth.currentSession?.accessToken;
  }

  String get _redirectUri {
    if (kIsWeb) {
      return AppConfig.appUrl;
    }
    return 'pistisai://callback';
  }

  UserModel _mapSupabaseUser(User user) {
    final createdAt =
        DateTime.tryParse(user.createdAt) ?? DateTime.now();
    final updatedAt =
        DateTime.tryParse(user.updatedAt ?? user.createdAt) ?? createdAt;

    return UserModel(
      id: user.id,
      email: user.email ?? '',
      name: user.userMetadata?['name'] as String? ??
          user.userMetadata?['full_name'] as String?,
      nickname: user.userMetadata?['nickname'] as String?,
      picture: user.userMetadata?['avatar_url'] as String?,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  Future<void> _persistSession(Session session) async {
    try {
      await _storage.write(
        key: 'supabase_access_token',
        value: session.accessToken,
      );
      final refreshToken = session.refreshToken;
      if (refreshToken != null) {
        await _storage.write(
          key: 'supabase_refresh_token',
          value: refreshToken,
        );
      }
    } catch (e) {
      debugPrint('[SupabaseAuthProvider] Failed to persist session: $e');
    }
  }

  Future<void> _clearPersistedSession() async {
    try {
      await _storage.delete(key: 'supabase_access_token');
      await _storage.delete(key: 'supabase_refresh_token');
    } catch (e) {
      debugPrint('[SupabaseAuthProvider] Failed to clear session: $e');
    }
  }
}
