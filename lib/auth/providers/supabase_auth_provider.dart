import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pistisai/auth/auth_provider.dart';
import 'package:pistisai/models/user_model.dart';
import 'package:pistisai/services/secure_storage_service.dart';
import 'package:pistisai/config/app_config.dart';

/// Supabase Auth Provider
/// Handles authentication via Supabase (email/password, magic link, OAuth).
class SupabaseAuthProvider extends AuthProvider {
  final SecureStorageService _secureStorage =
      SecureStorageService.instance;

  SupabaseAuthProvider() {
    _init();
  }

  Future<void> _init() async {
    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      final session = data.session;
      if (session != null) {
        _persistSession(session);
      } else {
        _clearPersistedSession();
      }
    });
  }

  @override
  Future<bool> get isLoggedIn async {
    final session = Supabase.instance.client.auth.currentSession;
    return session != null;
  }

  @override
  Future<UserModel?> get currentUser async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return null;
    return _mapSupabaseUser(user);
  }

  @override
  Future<AuthResult> login(String email, String password) async {
    try {
      final response = await Supabase.instance.client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      if (response.session == null) {
        return AuthResult('Login failed: no session returned');
      }
      await _persistSession(response.session!);
      return AuthResult(null, _mapSupabaseUser(response.user!));
    } on AuthException catch (e) {
      return AuthResult(e.message);
    } catch (e) {
      return AuthResult('Unexpected error: $e');
    }
  }

  @override
  Future<AuthResult> loginWithGoogle() async {
    try {
      final result = await Supabase.instance.client.auth.signInWithOAuth(
        Provider.google,
        redirectTo: _getRedirectUri(),
      );
      if (!result) {
        return AuthResult('Google sign-in failed');
      }
      // Session will be set via auth state change listener
      return AuthResult(null);
    } catch (e) {
      return AuthResult('Google sign-in error: $e');
    }
  }

  @override
  Future<AuthResult> sendMagicLink(String email) async {
    try {
      await Supabase.instance.client.auth.signInWithOtp(
        email: email,
        emailRedirectTo: _getRedirectUri(),
      );
      return AuthResult(null);
    } on AuthException catch (e) {
      return AuthResult(e.message);
    } catch (e) {
      return AuthResult('Magic link error: $e');
    }
  }

  @override
  Future<AuthResult> register(String email, String password) async {
    try {
      final response = await Supabase.instance.client.auth.signUp(
        email: email,
        password: password,
        emailRedirectTo: _getRedirectUri(),
      );
      if (response.user == null) {
        return AuthResult('Registration failed');
      }
      return AuthResult(null, _mapSupabaseUser(response.user!));
    } on AuthException catch (e) {
      return AuthResult(e.message);
    } catch (e) {
      return AuthResult('Registration error: $e');
    }
  }

  @override
  Future<void> logout() async {
    try {
      await Supabase.instance.client.auth.signOut();
      await _clearPersistedSession();
    } catch (e) {
      debugPrint('Logout error: $e');
    }
  }

  @override
  Future<AuthResult> refreshSession() async {
    try {
      final session = Supabase.instance.client.auth.currentSession;
      if (session == null) {
        return AuthResult('No session to refresh');
      }
      final response = await Supabase.instance.client.auth.refreshSession();
      if (response.session == null) {
        return AuthResult('Session refresh failed');
      }
      await _persistSession(response.session!);
      return AuthResult(null);
    } catch (e) {
      return AuthResult('Refresh error: $e');
    }
  }

  @override
  Future<String?> getAccessToken() async {
    return Supabase.instance.client.auth.currentSession?.accessToken;
  }

  @override
  Future<String?> getUserId() async {
    return Supabase.instance.client.auth.currentUser?.id;
  }

  String _getRedirectUri() {
    if (kIsWeb) {
      return AppConfig.appUrl;
    }
    return 'pistisai://callback';
  }

  UserModel _mapSupabaseUser(User user) {
    return UserModel(
      id: user.id,
      email: user.email ?? '',
      name: user.userMetadata?['name'] ??
          user.userMetadata?['full_name'] ??
          user.email ??
          '',
      nickname: user.userMetadata?['nickname'] ?? '',
      avatarUrl: user.userMetadata?['avatar_url'] ?? '',
      createdAt: user.createdAt,
      lastSignInAt: user.lastSignInAt ?? user.createdAt,
    );
  }

  Future<void> _persistSession(Session session) async {
    try {
      await _secureStorage.setString(
        'supabase_access_token',
        session.accessToken,
      );
      if (session.refreshToken != null) {
        await _secureStorage.setString(
          'supabase_refresh_token',
          session.refreshToken!,
        );
      }
    } catch (e) {
      debugPrint('Failed to persist session: $e');
    }
  }

  Future<void> _clearPersistedSession() async {
    try {
      await _secureStorage.delete('supabase_access_token');
      await _secureStorage.delete('supabase_refresh_token');
    } catch (e) {
      debugPrint('Failed to clear session: $e');
    }
  }
}
