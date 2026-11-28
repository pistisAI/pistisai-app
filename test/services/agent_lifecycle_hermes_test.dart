import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pistisai/services/agent_lifecycle_service.dart';
import 'package:pistisai/services/connection_manager_service.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// A Hermes connection as the app has it today: connected and healthy over
/// HTTP, with no gateway WebSocket channel.
class _HermesConnection extends ChangeNotifier
    implements ConnectionManagerService {
  final StreamController<Map<String, dynamic>> _messages =
      StreamController<Map<String, dynamic>>.broadcast();

  @override
  BackendType? get currentBackend => BackendType.hermes;

  @override
  bool get isConnected => true;

  @override
  bool isGatewayHealthy() => true;

  @override
  WebSocketChannel? get wsChannel => null;

  @override
  Stream<Map<String, dynamic>> get messageStream => _messages.stream;

  @override
  void dispose() {
    _messages.close();
    super.dispose();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('AgentLifecycleService on Hermes (#1042)', () {
    late _HermesConnection connection;
    late AgentLifecycleService service;

    setUp(() {
      connection = _HermesConnection();
      service = AgentLifecycleService(connectionManager: connection);
    });

    tearDown(() {
      service.dispose();
      connection.dispose();
    });

    test('is not ready without a gateway channel', () {
      expect(service.isReady, isFalse);
    });

    test('a Hermes connection change does not start an agent.list request',
        () async {
      connection.notifyListeners();
      await Future<void>.delayed(Duration.zero);
      expect(service.isLoading, isFalse);
    });

    test('listAgents fails fast instead of waiting for a timeout', () async {
      final watch = Stopwatch()..start();
      await expectLater(service.listAgents(), throwsException);
      expect(watch.elapsed, lessThan(const Duration(seconds: 2)));
      expect(service.lastError, AgentLifecycleService.notAvailableMessage);
    });

    test('start, stop and status fail fast and report not available',
        () async {
      final watch = Stopwatch()..start();
      final started = await service.startAgent('a1');
      final stopped = await service.stopAgent('a1');
      final status = await service.getAgentStatus('a1');
      expect(watch.elapsed, lessThan(const Duration(seconds: 2)));
      expect(started.success, isFalse);
      expect(started.message, AgentLifecycleService.notAvailableMessage);
      expect(stopped.success, isFalse);
      expect(status, isNull);
    });
  });
}
