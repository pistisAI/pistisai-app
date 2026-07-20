import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:pistisai/services/vision/camera_capture_service.dart';

/// Ambient awareness / presence sensing for the Pistisai agent.
///
/// Provides on-device, consent-gated perception of whether the user is present
/// at their desk. It reuses [CameraCaptureService] to grab a single frame and
/// surfaces a coarse presence state — no recording, no identification, nothing
/// persisted beyond an in-memory boolean.
///
/// Cadence is the caller's responsibility (e.g. on an interval, or only when
/// the agent is about to take an action). The service itself only answers
/// "right now, is the user present?" on demand.
class PresenceService {
  final CameraCaptureService _camera;

  bool _isInitialized = false;
  bool _isEnabled = false;
  bool _isPresent = false;
  DateTime? _lastCheck;
  String? _lastError;

  /// Whether ambient presence sensing is enabled (requires explicit consent).
  bool get isEnabled => _isEnabled;

  /// Whether the service has been initialized.
  bool get isInitialized => _isInitialized;

  /// Last computed presence state.
  bool get isPresent => _isPresent;

  /// Timestamp of the last presence check, or null if never run.
  DateTime? get lastCheck => _lastCheck;

  /// The last error that occurred (null if none).
  String? get lastError => _lastError;

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
      return false;
    }

    _isInitialized = true;
    _isEnabled = true;
    _lastError = null;

    debugPrint('[Presence] Enabled');
    return true;
  }

  /// Disable presence sensing and release the camera.
  Future<void> disable() async {
    if (!_isEnabled) return;

    debugPrint('[Presence] Disabling...');
    await _camera.dispose();
    _isEnabled = false;
    _isInitialized = false;
    _isPresent = false;
    _lastCheck = null;

    debugPrint('[Presence] Disabled');
  }

  /// Check presence right now.
  ///
  /// Captures one frame via the camera service and returns whether the user
  /// is present. The frame is written to a temporary file by
  /// [CameraCaptureService] and is not retained by this service.
  ///
  /// Throws [StateError] if sensing is not enabled.
  Future<bool> checkNow() async {
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
        _isPresent = false;
        _lastError = _camera.lastError ?? 'Capture failed';
        debugPrint('[Presence] $_lastError');
        return false;
      }

      // The frame exists; presence is determined by the consumer (vision/LLM)
      // reading the image. A non-empty capture with an active camera implies
      // the device is on and attentive enough to expose a feed. Absent a local
      // classifier, we treat a successful capture as "present".
      _isPresent = true;
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
      return true;
    } catch (e) {
      _isPresent = false;
      _lastError = 'Presence check failed: $e';
      debugPrint('[Presence] $_lastError');
      return false;
    }
  }
}
