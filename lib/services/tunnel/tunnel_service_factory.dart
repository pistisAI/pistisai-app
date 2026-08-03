/// Tunnel Service Factory
/// Factory methods for creating tunnel service instances
library;

import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:stream_channel/stream_channel.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../auth_service.dart';
import 'connection_recovery.dart';
import 'connection_state_tracker.dart';
import 'error_recovery_strategy.dart';
import 'interfaces/interfaces.dart';
import 'metrics_collector.dart' as metrics_impl;
import 'persistent_request_queue.dart';
import 'reconnection_manager.dart';
import 'tunnel_config_manager.dart';
import 'tunnel_service_impl.dart';
import 'websocket_heartbeat.dart';

/// An inert [WebSocketChannel] backed by an in-memory [StreamChannelController].
///
/// It never opens a real socket, so it is safe to construct in unit tests and
/// before a transport is established. The real, connected channel should be
/// supplied by the caller via the factory's `channel` argument once available.
class _InertWebSocketChannel extends StreamChannelMixin
    implements WebSocketChannel {
  final StreamChannelController<dynamic> _controller =
      StreamChannelController<dynamic>();

  @override
  Stream get stream => _controller.local.stream;

  @override
  WebSocketSink get sink => _InertWebSocketSink(_controller.local.sink);

  @override
  String? get protocol => null;

  @override
  int? get closeCode => null;

  @override
  String? get closeReason => null;

  @override
  Future<void> get ready => Future<void>.value();
}

/// A [WebSocketSink] that forwards to an in-memory [StreamSink].
class _InertWebSocketSink implements WebSocketSink {
  final StreamSink<dynamic> _inner;

  _InertWebSocketSink(this._inner);

  @override
  void add(dynamic data) => _inner.add(data);

  @override
  void addError(Object error, [StackTrace? stackTrace]) =>
      _inner.addError(error, stackTrace);

  @override
  Future addStream(Stream stream) => _inner.addStream(stream);

  @override
  Future close([int? closeCode, String? closeReason]) => _inner.close();

  @override
  Future get done => _inner.done;
}

/// Factory for creating tunnel services
class TunnelServiceFactory {
  /// Create a tunnel service instance
  ///
  /// Wires all resolved tunnel components (reconnection manager, state
  /// tracker, heartbeat, recovery, request queue, metrics collector, error
  /// recovery strategy and config manager) into a concrete
  /// [TunnelServiceImpl].
  ///
  /// [channel] is optional. When absent, an inert disconnect-capable channel
  /// is used so the service can be constructed and used for config/diagnostics
  /// without a live socket. The caller should pass a real channel once one is
  /// established.
  static Future<TunnelService> createTunnelService({
    required AuthService authService,
    TunnelConfig? config,
    WebSocketChannel? channel,
  }) async {
    final cfg = config ?? const TunnelConfig();
    final prefs = await SharedPreferences.getInstance();

    final stateTracker = ConnectionStateTracker();
    final reconnectionManager = ReconnectionManager(
      maxAttempts: cfg.maxReconnectAttempts,
      baseDelay: cfg.reconnectBaseDelay,
      maxDelay: const Duration(seconds: 30),
    );

    // Build an inert channel when none is supplied so the service can be
    // constructed without an established transport. The caller can pass a
    // real, connected channel via [channel] once a transport exists.
    final wsChannel = channel ?? _InertWebSocketChannel();

    final heartbeat = WebSocketHeartbeat(
      channel: wsChannel,
      pingInterval: const Duration(seconds: 30),
      pongTimeout: const Duration(seconds: 45),
      onConnectionLost: () {
        stateTracker.updateState(TunnelConnectionState.reconnecting);
      },
    );

    final requestQueue = PersistentRequestQueue(maxSize: cfg.maxQueueSize);
    final metricsCollector = metrics_impl.MetricsCollector();

    final recovery = ConnectionRecovery(
      reconnectionManager: reconnectionManager,
      stateTracker: stateTracker,
      connectFunction: () async {
        // Simulated connect for the scaffolded transport. Replace when a
        // real WebSocket connection is wired in.
        await Future<void>.delayed(const Duration(milliseconds: 100));
      },
      requestQueue: requestQueue,
    );

    final configManager = TunnelConfigManager();
    await configManager.initialize();

    final errorRecovery = ErrorRecoveryStrategy(
      reconnectionManager: reconnectionManager,
      testConnection: () async =>
          stateTracker.currentState == TunnelConnectionState.connected,
      reconnect: () async => recovery.handleDisconnection(
        reason: 'Error recovery triggered reconnect',
        autoReconnect: true,
      ),
      flushQueuedRequests: () async {
        while (true) {
          final next = await requestQueue.dequeue();
          if (next == null) break;
        }
      },
    );

    return TunnelServiceImpl(
      reconnectionManager: reconnectionManager,
      stateTracker: stateTracker,
      heartbeat: heartbeat,
      recovery: recovery,
      requestQueue: requestQueue,
      metricsCollector: metricsCollector,
      errorRecovery: errorRecovery,
      configManager: configManager,
      config: cfg,
      prefs: prefs,
    );
  }

  /// Create a request queue instance
  static RequestQueue createRequestQueue({
    int maxSize = 100,
    bool enablePersistence = true,
  }) {
    return PersistentRequestQueue(maxSize: maxSize);
  }

  /// Create a metrics collector instance
  static metrics_impl.MetricsCollector createMetricsCollector({
    int maxHistorySize = 1000,
  }) {
    return metrics_impl.MetricsCollector();
  }

  /// Create a tunnel service with all dependencies bundled
  static Future<Map<String, dynamic>> createFullTunnelStack({
    required AuthService authService,
    TunnelConfig? config,
    int maxQueueSize = 100,
    int maxHistorySize = 1000,
    WebSocketChannel? channel,
  }) async {
    final cfg =
        config ?? TunnelConfig(maxQueueSize: maxQueueSize);
    final service = await createTunnelService(
      authService: authService,
      config: cfg,
      channel: channel,
    );
    final queue = createRequestQueue(maxSize: maxQueueSize);
    final metrics = createMetricsCollector(maxHistorySize: maxHistorySize);

    return {
      'service': service,
      'queue': queue,
      'metrics': metrics,
    };
  }
}