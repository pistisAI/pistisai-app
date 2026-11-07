import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:pistisai/auth/access_login_flow.dart';
import 'package:pistisai/auth/access_token_store.dart';
import 'package:pistisai/auth/auth_provider.dart';
import 'package:pistisai/auth/cloudflare_access_config.dart';
import 'package:pistisai/models/user_model.dart';
import 'package:pistisai/services/enhanced_user_tier_service.dart';

/// Opens the Access login URL and returns the CF_Authorization token, or
/// null when the person cancels.
typedef AccessLoginFlow = Future<String?> Function(Uri loginUrl);

/// Tunnel sign-in. Local use stays signed out. Free tier opens Cloudflare
/// Access. Business and Enterprise skip Access entirely.
class CloudflareAccessAuthProvider extends AuthProvider {
  CloudflareAccessAuthProvider({
    AccessTokenStore? store,
    AccessLoginFlow? loginFlow,
    UserTier Function()? currentTier,
    this.emailFromToken,
  })  : _store = store ?? SecureAccessTokenStore(),
        _loginFlow = loginFlow,
        _currentTier = currentTier ?? _defaultTier;

  final AccessTokenStore _store;
  final AccessLoginFlow? _loginFlow;
  final UserTier Function() _currentTier;

  /// Optional parser so tests can observe an email without a JWT library.
  final String? Function(String token)? emailFromToken;

  final StreamController<bool> _authStateController =
      StreamController<bool>.broadcast();

  UserModel? _currentUser;
  String? _accessToken;
  bool _customerNetwork = false;

  static UserTier _defaultTier() => UserTier.free;

  @override
  Stream<bool> get authStateChanges => _authStateController.stream;

  @override
  UserModel? get currentUser => _currentUser;

  bool get customerNetwork => _customerNetwork;

  bool get accessRequired => !tierUsesCustomerNetwork(_currentTier());

  @override
  Future<String?> getAccessToken() async {
    if (_customerNetwork) return null;
    return _accessToken;
  }

  @override
  Future<void> initialize() async {
    if (tierUsesCustomerNetwork(_currentTier())) {
      _adoptCustomerNetwork();
      return;
    }
    _customerNetwork = false;
    final stored = await _store.read();
    if (stored != null && stored.isNotEmpty) {
      _acceptToken(stored);
    } else {
      _currentUser = null;
      _accessToken = null;
      _authStateController.add(false);
    }
  }

  @override
  Future<void> login() async {
    if (tierUsesCustomerNetwork(_currentTier())) {
      _adoptCustomerNetwork();
      return;
    }
    final flow = _loginFlow ?? openAccessLogin;
    final token = await flow(CloudflareAccessConfig.loginUri());
    if (token == null || token.isEmpty) return;
    _acceptToken(token);
    await _store.write(token);
  }

  @override
  Future<void> logout() async {
    _currentUser = null;
    _accessToken = null;
    _customerNetwork = false;
    await _store.clear();
    _authStateController.add(false);
  }

  @override
  Future<bool> handleCallback({String? url}) async {
    if (tierUsesCustomerNetwork(_currentTier())) {
      _adoptCustomerNetwork();
      return true;
    }
    if (url == null || url.isEmpty) return _accessToken != null;
    final token = tokenFromCallback(url);
    if (token == null || token.isEmpty) return false;
    _acceptToken(token);
    await _store.write(token);
    return true;
  }

  @override
  Future<void> loginMockDeveloper() async {
    if (kReleaseMode) return;
    _customerNetwork = false;
    _accessToken = 'dev-bypass';
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

  void _adoptCustomerNetwork() {
    _customerNetwork = true;
    _accessToken = null;
    _currentUser = UserModel(
      id: 'customer-network',
      email: '',
      name: 'Customer network',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    _authStateController.add(true);
  }

  void _acceptToken(String token) {
    _customerNetwork = false;
    _accessToken = token;
    final email = emailFromToken?.call(token) ?? '';
    _currentUser = UserModel(
      id: email.isEmpty ? 'access-user' : email,
      email: email,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    _authStateController.add(true);
  }
}

/// Pull a CF_Authorization value out of an Access redirect.
String? tokenFromCallback(String url) {
  final uri = Uri.tryParse(url);
  if (uri == null) return null;
  for (final key in const [
    'token',
    'cf_access_token',
    'CF_Authorization',
  ]) {
    final value = uri.queryParameters[key];
    if (value != null && value.isNotEmpty) return value;
  }
  return null;
}

/// Headers for a free-tier tunnel request. Customer networks send nothing.
Map<String, String> tunnelAccessHeaders({
  required bool customerNetwork,
  required String? accessToken,
}) {
  if (customerNetwork) return const {};
  if (accessToken == null || accessToken.isEmpty) return const {};
  return {
    'cf-access-token': accessToken,
    'Cf-Access-Jwt-Assertion': accessToken,
  };
}
