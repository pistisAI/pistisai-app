import 'dart:async';

import '../../models/user_model.dart';
import '../auth_provider.dart';

/// No-op AuthProvider for testing and OpenClaw gateway connections
/// that don't require user authentication
class NoopAuthProvider implements AuthProvider {
  final StreamController<bool> _authStateController = StreamController<bool>.broadcast();

  @override
  Stream<bool> get authStateChanges => _authStateController.stream;

  @override
  UserModel? get currentUser => null;

  @override
  Future<void> initialize() async {
    _authStateController.add(false);
  }

  @override
  Future<void> login() async {}

  @override
  Future<void> logout() async {}

  @override
  Future<bool> handleCallback({String? url}) async => false;

  @override
  Future<String?> getAccessToken() async => null;

  @override
  Future<void> loginMockDeveloper() async {}

  void dispose() {
    _authStateController.close();
  }
}