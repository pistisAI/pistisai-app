import 'dart:async';

import 'package:pistisai/auth/auth_provider.dart';
import 'package:pistisai/models/user_model.dart';
import 'package:pistisai/services/auth_service.dart';
import 'package:pistisai/services/tunnel/interfaces/interfaces.dart';
import 'package:pistisai/services/tunnel/metrics_collector.dart' as metrics_impl;
import 'package:pistisai/services/tunnel/persistent_request_queue.dart';
import 'package:pistisai/services/tunnel/tunnel_service_factory.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _StubAuthProvider implements AuthProvider {
  final StreamController<bool> _authStateController =
      StreamController<bool>.broadcast();

  @override
  Stream<bool> get authStateChanges => _authStateController.stream;

  @override
  UserModel? get currentUser => null;

  @override
  Future<void> initialize() async {}

  @override
  Future<void> login() async {}

  @override
  Future<void> logout() async {}

  @override
  Future<String?> getAccessToken() async => null;

  @override
  Future<bool> handleCallback({String? url}) async => false;

  @override
  Future<void> loginMockDeveloper() async {}

  void dispose() {
    _authStateController.close();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TunnelServiceFactory', () {
    late _StubAuthProvider authProvider;
    late AuthService authService;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      authProvider = _StubAuthProvider();
      authService = AuthService(authProvider);
    });

    tearDown(() {
      authProvider.dispose();
      authService.dispose();
    });

    test('createRequestQueue returns the concrete queue implementation', () {
      final queue = TunnelServiceFactory.createRequestQueue(maxSize: 24);

      expect(queue, isA<PersistentRequestQueue>());
      expect(queue.size, 0);
      expect(queue.isEmpty, isTrue);
    });

    test('createMetricsCollector returns the concrete metrics implementation', () {
      final collector = TunnelServiceFactory.createMetricsCollector(maxHistorySize: 1000);

      expect(collector, isA<metrics_impl.MetricsCollector>());

      for (var i = 0; i < 20; i++) {
        collector.recordRequest(
          latency: Duration(milliseconds: i),
          success: true,
        );
      }
    });

    test('createTunnelService returns a concrete TunnelServiceImpl', () async {
      final service = await TunnelServiceFactory.createTunnelService(
        authService: authService,
        config: const TunnelConfig(
          maxQueueSize: 50,
          maxReconnectAttempts: 3,
        ),
      );

      expect(service, isA<TunnelService>());
    });

    test('createFullTunnelStack returns the concrete stack entries', () async {
      final stack = await TunnelServiceFactory.createFullTunnelStack(
        authService: authService,
        config: const TunnelConfig(maxQueueSize: 33),
        maxQueueSize: 11,
        maxHistorySize: 22,
      );

      expect(stack['service'], isA<TunnelService>());
      expect(stack['queue'], isA<PersistentRequestQueue>());
      expect(stack['metrics'], isA<metrics_impl.MetricsCollector>());
    });
  });
}
