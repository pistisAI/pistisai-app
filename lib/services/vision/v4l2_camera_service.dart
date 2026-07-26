import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

/// Linux (v4l2) camera capture via ffmpeg.
///
/// The official `camera` plugin has no Linux backend, and `camera_desktop`
/// requests RGBA frames the camera cannot produce (this cam is YUYV-only),
/// so it times out. This service captures directly with ffmpeg — which does
/// the YUYV→RGBA conversion itself — and exposes raw frames for a preview
/// texture. Frames stay local; nothing is transmitted.
///
/// Capture is started on demand (explicit consent), frames are delivered to
/// a [ValueNotifier] carrying the latest RGBA bytes, and the consumer
/// (preview widget) copies them into a Flutter [Texture].
class V4L2CameraService {
  static const int width = 640;
  static const int height = 480;
  static const int bytesPerPixel = 4; // RGBA
  static const int frameBytes = width * height * bytesPerPixel;

  final String device;
  Process? _process;
  StreamSubscription<List<int>>? _stdoutSub;

  final ValueNotifier<Uint8List?> latestFrame = ValueNotifier<Uint8List?>(null);
  bool _running = false;
  final List<int> _buf = [];
  V4L2CameraService({this.device = '/dev/video0'});

  bool get isRunning => _running;

  /// Start capturing. Throws if ffmpeg is unavailable or the device fails.
  Future<void> start() async {
    if (_running) return;
    final ffmpeg = await _ffmpegPath();
    if (ffmpeg == null) {
      throw StateError('ffmpeg not found on PATH — cannot capture on Linux');
    }

    _buf.clear();
    _running = true;

    _process = await Process.start(ffmpeg, [
      '-f', 'v4l2',
      '-input_format', 'yuyv422',
      '-i', device,
      '-f', 'rawvideo',
      '-pix_fmt', 'rgb0', // RGBA, little-endian — matches Flutter rgba8888
      '-', // stdout
    ]);

    _process!.stderr.listen((d) {
      final s = String.fromCharCodes(d);
      if (s.toLowerCase().contains('error') ||
          s.toLowerCase().contains('fail')) {
        debugPrint('[V4L2Camera] ffmpeg: $s');
      }
    });

    _stdoutSub = _process!.stdout.listen(_onData);
    debugPrint('[V4L2Camera] capture started on $device');
  }

  void _onData(List<int> chunk) {
    _buf.addAll(chunk);
    // Pull complete frames off the front of the buffer.
    while (_buf.length >= frameBytes) {
      final frame = Uint8List.fromList(
        _buf.sublist(0, frameBytes),
      );
      latestFrame.value = frame;
      _buf.removeRange(0, frameBytes);
    }
  }

  /// Capture a single still image to a temp file (local only).
  Future<String?> captureStill() async {
    final dir = await Directory.systemTemp.createTemp('pistisai_cam_');
    final out = '${dir.path}/still.jpg';
    final ffmpeg = await _ffmpegPath();
    if (ffmpeg == null) return null;
    final result = await Process.run(ffmpeg, [
      '-y',
      '-f', 'v4l2',
      '-input_format', 'yuyv422',
      '-i', device,
      '-frames:v', '1',
      out,
    ]);
    if (result.exitCode != 0) {
      debugPrint('[V4L2Camera] still capture failed: ${result.stderr}');
      return null;
    }
    return out;
  }

  Future<String?> _ffmpegPath() async {
    for (final c in ['ffmpeg', '/usr/bin/ffmpeg', '/usr/local/bin/ffmpeg']) {
      try {
        final r = await Process.run('which', [c == 'ffmpeg' ? 'ffmpeg' : c]);
        if (r.exitCode == 0 && r.stdout.toString().trim().isNotEmpty) {
          return r.stdout.toString().trim();
        }
      } catch (_) {}
    }
    // fallback: assume on PATH
    return 'ffmpeg';
  }

  Future<void> stop() async {
    _running = false;
    await _stdoutSub?.cancel();
    _stdoutSub = null;
    _process?.kill(ProcessSignal.sigterm);
    _process = null;
    latestFrame.value = null;
    debugPrint('[V4L2Camera] capture stopped');
  }
}
