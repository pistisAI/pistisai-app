import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'package:pistisai/services/vision/v4l2_camera_service.dart';

/// A live camera preview backed by [V4L2CameraService] (Linux/v4l2 via ffmpeg).
///
/// Each new RGBA frame from the service is decoded into a [ui.Image] and
/// repainted. Local-only: frames are never saved or transmitted by this widget.
class V4L2CameraPreview extends StatefulWidget {
  final V4L2CameraService service;
  const V4L2CameraPreview({super.key, required this.service});

  @override
  State<V4L2CameraPreview> createState() => _V4L2CameraPreviewState();
}

class _V4L2CameraPreviewState extends State<V4L2CameraPreview> {
  ui.Image? _image;
  bool _listening = false;

  @override
  void initState() {
    super.initState();
    widget.service.latestFrame.addListener(_onFrame);
    _listening = true;
  }

  void _onFrame() {
    final bytes = widget.service.latestFrame.value;
    if (bytes == null) return;
    ui.decodeImageFromPixels(
      bytes,
      V4L2CameraService.width,
      V4L2CameraService.height,
      ui.PixelFormat.rgba8888,
      _onDecoded,
    );
  }

  void _onDecoded(ui.Image image) {
    if (mounted) setState(() => _image = image);
  }

  @override
  Widget build(BuildContext context) {
    if (_image == null) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 8),
            Text('Starting camera…', style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }
    return RawImage(image: _image, fit: BoxFit.cover);
  }

  @override
  void dispose() {
    if (_listening) widget.service.latestFrame.removeListener(_onFrame);
    super.dispose();
  }
}
