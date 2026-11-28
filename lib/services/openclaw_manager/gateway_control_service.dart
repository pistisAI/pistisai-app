import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:pistisai/services/settings_preference_service.dart';

enum GatewayState {
  unknown,
  starting,
  running,
  stopping,
  stopped,
  error,
}

/// Runs a command; matches [Process.run] so tests can record calls.
typedef GatewayProcessRunner = Future<ProcessResult> Function(
  String executable,
  List<String> arguments,
);

/// Controls an OpenClaw Gateway through the `openclaw` CLI.
///
/// OpenClaw is an optional harness (#1042): this service never runs on its
/// own. It does not listen to the Hermes connection and is not registered
/// by the service locator, so a Hermes-only install never spawns the
/// `openclaw` CLI. Every command runs only when a caller asks for it
/// through [start], [stop], [restart], [checkStatus] or [getStatus].
class GatewayControlService extends ChangeNotifier {
  GatewayState _state = GatewayState.unknown;
  String? _errorMessage;
  DateTime? _startedAt;
  Timer? _healthCheckTimer;
  final SettingsPreferenceService _settings;
  bool _autoRestartEnabled = true;
  int _restartAttempts = 0;
  bool _isDisposed = false;
  static const int _maxRestartAttempts = 5;
  final GatewayProcessRunner _runProcess;

  GatewayControlService(
    this._settings, {
    @visibleForTesting GatewayProcessRunner? processRunner,
  }) : _runProcess = processRunner ?? Process.run {
    _loadAutoRestartSetting();
  }

  GatewayState get state => _state;
  String? get errorMessage => _errorMessage;
  DateTime? get startedAt => _startedAt;
  bool get isRunning => _state == GatewayState.running;
  bool get isStarting => _state == GatewayState.starting;
  bool get isStopping => _state == GatewayState.stopping;
  bool get autoRestartEnabled => _autoRestartEnabled;

  Future<void> _loadAutoRestartSetting() async {
    _autoRestartEnabled = await _settings.getGatewayAutoRestart() ?? true;
    if (!_isDisposed) {
      notifyListeners();
    }
  }

  Future<void> setAutoRestart(bool enabled) async {
    _autoRestartEnabled = enabled;
    await _settings.setGatewayAutoRestart(enabled);
    notifyListeners();
  }

  Future<bool> start() async {
    if (_state == GatewayState.running || _state == GatewayState.starting) {
      return true;
    }

    _state = GatewayState.starting;
    _errorMessage = null;
    notifyListeners();

    try {
      final result =
          await _runProcess('openclaw', ['gateway', 'start', '--json']);

      if (result.exitCode == 0) {
        _state = GatewayState.running;
        _startedAt = DateTime.now();
        _restartAttempts = 0;
        _startHealthCheck();
        notifyListeners();
        return true;
      } else {
        _state = GatewayState.error;
        _errorMessage = result.stderr.toString();
        notifyListeners();
        return false;
      }
    } catch (e) {
      _state = GatewayState.error;
      _errorMessage = 'Failed to start gateway: $e';
      notifyListeners();
      return false;
    }
  }

  Future<bool> stop() async {
    if (_state == GatewayState.stopped || _state == GatewayState.stopping) {
      return true;
    }
    if (_state == GatewayState.unknown) {
      // Nothing was stopped: the gateway state was never established, so
      // reporting success would be untrue (#857).
      _errorMessage = 'Gateway state is unknown; nothing was stopped';
      notifyListeners();
      return false;
    }

    _state = GatewayState.stopping;
    notifyListeners();

    try {
      final result =
          await _runProcess('openclaw', ['gateway', 'stop', '--json']);

      _healthCheckTimer?.cancel();
      _healthCheckTimer = null;

      if (result.exitCode == 0) {
        _state = GatewayState.stopped;
        _startedAt = null;
        notifyListeners();
        return true;
      } else {
        _state = GatewayState.error;
        _errorMessage = result.stderr.toString();
        notifyListeners();
        return false;
      }
    } catch (e) {
      _state = GatewayState.error;
      _errorMessage = 'Failed to stop gateway: $e';
      notifyListeners();
      return false;
    }
  }

  Future<bool> restart() async {
    await stop();
    return await start();
  }

  Future<void> checkStatus() async {
    try {
      final result =
          await _runProcess('openclaw', ['gateway', 'status', '--json']);

      if (result.exitCode == 0) {
        final output = result.stdout.toString();
        if (output.contains('running') || output.contains('active')) {
          if (_state != GatewayState.running) {
            _state = GatewayState.running;
            _startedAt ??= DateTime.now();
            _startHealthCheck();
            notifyListeners();
          }
        } else {
          if (_state != GatewayState.stopped) {
            _state = GatewayState.stopped;
            _healthCheckTimer?.cancel();
            notifyListeners();
          }
        }
      } else {
        if (_state != GatewayState.stopped) {
          _state = GatewayState.stopped;
          _healthCheckTimer?.cancel();
          notifyListeners();
        }
      }
    } catch (e) {
      if (_state != GatewayState.unknown) {
        _state = GatewayState.unknown;
        _errorMessage = 'Failed to check status: $e';
        notifyListeners();
      }
    }
  }

  void _startHealthCheck() {
    _healthCheckTimer?.cancel();
    _healthCheckTimer = Timer.periodic(const Duration(seconds: 30), (_) async {
      await checkStatus();

      // Auto-restart on crash if enabled
      if (_autoRestartEnabled && _state != GatewayState.running) {
        final wasPreviouslyRunning = _startedAt != null;
        if (wasPreviouslyRunning && _restartAttempts < _maxRestartAttempts) {
          _restartAttempts++;
          _errorMessage =
              'Gateway crashed, attempting auto-restart ($_restartAttempts/$_maxRestartAttempts)';
          notifyListeners();

          // Wait a bit before restarting to avoid rapid restart loops
          await Future.delayed(Duration(seconds: _restartAttempts * 2));

          final success = await start();
          if (success) {
            _restartAttempts = 0; // Reset counter on successful restart
          }
        } else if (_restartAttempts >= _maxRestartAttempts) {
          _errorMessage =
              'Gateway failed to restart after $_maxRestartAttempts attempts. Auto-restart disabled.';
          _autoRestartEnabled = false;
          notifyListeners();
        }
      }
    });
  }

  Future<Map<String, dynamic>> getStatus() async {
    await checkStatus();
    return {
      'state': _state.name,
      'isRunning': isRunning,
      'startedAt': _startedAt?.toIso8601String(),
      'errorMessage': _errorMessage,
    };
  }

  @override
  void dispose() {
    _isDisposed = true;
    _healthCheckTimer?.cancel();
    super.dispose();
  }
}
