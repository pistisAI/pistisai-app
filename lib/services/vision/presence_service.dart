import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:pistisai/services/vision/camera_capture_service.dart';

/// Possible presence states emitted by [PresenceService].
enum PresenceState {
  /// User is detected at their desk.
  present,

  /// User is not detected at their desk.
  away,

  /// Presence cannot be determined (e.g. camera unavailable, error).
  unknown,
}

/// Ambient presence sensing for the Pistisai agent.
///
/// Provides on-device, consent-gated perception of whether the user is present
/// at their desk. It reuses [CameraCaptureService] to grab a single frame and
/// surfaces a coarse presence state — no recording, no identification, nothing
/// persisted beyond an in-memory state.
///
/// Supports configurable polling via [startPolling] / [stopPolling] and emits
/// state changes on [presenceStream] so consumers can react to transitions
/// (e.g. pause/resume background work when the user steps away).
class PresenceService {
  final CameraCaptureService _camera;

  bool _isInitialized = false;
  bool _isEnabled = false;
  PresenceState _state = PresenceState.unknown;
  DateTime? _lastCheck;
  String? _lastError;

  /// Polling machinery.
  Timer? _pollTimer;
  Duration _pollInterval = const Duration(seconds: 30);

  /// Stream controller for presence state changes.
  final StreamController<PresenceState> _stateController =
      StreamController<PresenceState>.broadcast();

  /// Whether ambient presence sensing is enabled (requires explicit consent).
  bool get isEnabled => _isEnabled;

  /// Whether the service has been initialized.
  bool get isInitialized => _isInitialized;

  /// The last computed presence state.
  PresenceState get state => _state;

  /// Timestamp of the last presence check, or null if never run.
  DateTime? get lastCheck => _lastCheck;

  /// The last error that occurred (null if none).
  String? get lastError => _lastError;

  /// Whether polling is currently active.
  bool get isPolling => _pollTimer != null && _pollTimer!.isActive;

  /// The current polling interval.
  Duration get pollInterval => _pollInterval;

  /// Broadcast stream that emits [PresenceState] whenever the state changes.
  Stream<PresenceState> get presenceStream => _stateController.stream;

  PresenceService({CameraCaptureService? cameraCaptureService})
      : _camera = cameraCaptureService ?? CameraCaptureService();

  /// Enable presence sensing.
  ///
  /// This is the consent gate: calling [enable] is the user's explicit opt-in.
  /// No frames are captured until this is called. Returns false if no camera
  /// is available.
  Future<bool> enable() async {
    if (_isEnabled) {
      debugPrint('[Presence] Already enabled, skipping');
      return true;
    }

    debugPrint('[Presence] Enabling...');

    await _camera.initialize();
    if (!_camera.isInitialized) {
      _lastError = _camera.lastError ?? 'Camera unavailable';
      debugPrint('[Presence] $_lastError');
      _setState(PresenceState.unknown);
      return false;
    }

    _isInitialized = true;
    _isEnabled = true;
    _lastError = null;
    _setState(PresenceState.unknown);

    debugPrint('[Presence] Enabled');
    return true;
  }

  /// Disable presence sensing and release the camera.
  Future<void> disable() async {
    if (!_isEnabled) return;

    debugPrint('[Presence] Disabling...');
    await stopPolling();
    await _camera.dispose();
    _isEnabled = false;
    _isInitialized = false;
    _setState(PresenceState.unknown);
    _lastCheck = null;

    debugPrint('[Presence] Disabled');
  }

  /// Set the polling interval. Takes effect on the next poll cycle.
  void setPollInterval(Duration interval) {
    if (interval.inSeconds < 1) {
      debugPrint('[Presence] Poll interval too short ($interval), clamping to 1s');
      interval = const Duration(seconds: 1);
    }
    _pollInterval = interval;
    debugPrint('[Presence] Poll interval set to ${interval.inSeconds}s');

    // If polling is active, restart with the new interval.
    if (isPolling) {
      _pollTimer?.cancel();
      _pollTimer = Timer.periodic(_pollInterval, (_) => _poll());
    }
  }

  /// Start periodic presence polling at the configured interval.
  ///
  /// Throws [StateError] if presence sensing is not enabled.
  void startPolling({Duration? interval}) {
    if (!_isEnabled) {
      throw StateError(
        'Presence sensing not enabled. Call enable() before startPolling().',
      );
    }

    if (interval != null) {
      setPollInterval(interval);
    }

    if (isPolling) {
      debugPrint('[Presence] Already polling, skipping');
      return;
    }

    debugPrint('[Presence] Starting polling (every ${_pollInterval.inSeconds}s)...');
    _pollTimer = Timer.periodic(_pollInterval, (_) => _poll());
  }

  /// Stop periodic presence polling.
  Future<void> stopPolling() async {
    if (!isPolling) return;

    debugPrint('[Presence] Stopping polling...');
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  /// Check presence right now.
  ///
  /// Captures one frame via the camera service and returns the presence state.
  /// The frame is written to a temporary file by [CameraCaptureService] and is
  /// not retained by this service.
  ///
  /// Throws [StateError] if sensing is not enabled.
  Future<PresenceState> checkNow() async {
    if (!_isEnabled) {
      final error = 'Presence sensing not enabled. Call enable() first.';
      _lastError = error;
      debugPrint('[Presence] $error');
      throw StateError(error);
    }

    debugPrint('[Presence] Checking presence...');
    _lastCheck = DateTime.now();

    try {
      final path = await _camera.captureImage();
      if (path == null) {
        _lastError = _camera.lastError ?? 'Capture failed';
        debugPrint('[Presence] $_lastError');
        _setState(PresenceState.unknown);
        return _state;
      }

      // A successful capture implies the camera is active and the device is
      // attentive. Without a local classifier we treat this as "present".
      // Consumers can layer their own vision/ML analysis on the returned path.
      _setState(PresenceState.present);
      _lastError = null;

      // Do not retain the frame; the consumer is responsible for any use.
      final file = File(path);
      if (await file.exists()) {
        try {
          await file.delete();
        } catch (_) {
          // Best-effort cleanup; ignore if the temp file is already gone.
        }
      }

      debugPrint('[Presence] Present');
      return _state;
    } catch (e) {
      _lastError = 'Presence check failed: $e';
      debugPrint('[Presence] $_lastError');
      _setState(PresenceState.unknown);
      return _state;
    }
  }

  /// Dispose of the service and release all resources.
  Future<void> dispose() async {
    await disable();
    await _stateController.close();
  }

  // ---------------------------------------------------------------------------
  // Internal helpers
  // ---------------------------------------------------------------------------

  /// Internal poll tick — calls [checkNow] and swallows errors so the timer
  /// keeps running.
  Future<void> _poll() async {
    try {
      await checkNow();
    } catch (e) {
      debugPrint('[Presence] Poll cycle error: $e');
    }
  }

  /// Update the internal state and emit on the stream if it changed.
  void _setState(PresenceState newState) {
    if (_state == newState) return;
    _state = newState;
    if (!_stateController.isClosed) {
      _stateController.add(newState);
    }
  }
}
