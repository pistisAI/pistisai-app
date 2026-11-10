import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:pistisai/auth/auth_provider.dart';
import 'package:pistisai/config/app_config.dart';
import 'package:pistisai/models/user_model.dart';

/// Cloudflare Access is the only identity path.
///
/// The team domain and application audience come from the baked brand, and a
/// build define can override them. Login opens the app URL so Access can challenge. The
/// callback may carry the Access JWT as `token` or `cf_jwt`.
class CloudflareAccessAuthProvider extends AuthProvider {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  final StreamController<bool> _authStateController =
      StreamController<bool>.broadcast();

  UserModel? _currentUser;
  String? _accessToken;

  static const String _tokenKey = 'cf_access_jwt';

  bool get _configured =>
      AppConfig.cloudflareAccessTeamDomain.isNotEmpty &&
      AppConfig.cloudflareAccessAud.isNotEmpty;

  @override
  Stream<bool> get authStateChanges => _authStateController.stream;

  @override
  UserModel? get currentUser => _currentUser;

  @override
  Future<void> initialize() async {
    _accessToken = await _storage.read(key: _tokenKey);
    if (_accessToken == null || _accessToken!.isEmpty) {
      _currentUser = null;
      _authStateController.add(false);
      return;
    }
    _currentUser = _userFromJwt(_accessToken!);
    _authStateController.add(_currentUser != null);
  }

  @override
  Future<void> login() async {
    if (!_configured) {
      return;
    }
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
    try {
      await _storage.delete(key: _tokenKey);
    } catch (e) {
      debugPrint('[CloudflareAccessAuthProvider] Failed to clear session: $e');
    }
  }

  @override
  Future<bool> handleCallback({String? url}) async {
    if (url == null || url.isEmpty) {
      return _accessToken != null;
    }
    final token = _tokenFromCallback(url);
    if (token == null || token.isEmpty) {
      return false;
    }
    _accessToken = token;
    _currentUser = _userFromJwt(token);
    try {
      await _storage.write(key: _tokenKey, value: token);
    } catch (e) {
      debugPrint(
          '[CloudflareAccessAuthProvider] Failed to persist session: $e');
    }
    _authStateController.add(_currentUser != null);
    return _currentUser != null;
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

  String? _tokenFromCallback(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) {
      return null;
    }
    return uri.queryParameters['cf_jwt'] ?? uri.queryParameters['token'];
  }

  UserModel? _userFromJwt(String token) {
    final parts = token.split('.');
    if (parts.length < 2) {
      return null;
    }
    try {
      final normalized = base64Url.normalize(parts[1]);
      final claims = jsonDecode(utf8.decode(base64Url.decode(normalized)))
          as Map<String, dynamic>;
      final now = DateTime.now();
      return UserModel(
        id: claims['sub'] as String? ?? '',
        email: claims['email'] as String? ?? '',
        name: claims['name'] as String?,
        createdAt: now,
        updatedAt: now,
      );
    } catch (e) {
      debugPrint(
          '[CloudflareAccessAuthProvider] Could not read token claims: $e');
      return null;
    }
  }
}
