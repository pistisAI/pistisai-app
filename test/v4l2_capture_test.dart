import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pistisai/services/vision/v4l2_camera_service.dart';

void main() {
  test('v4l2 service captures real frames from /dev/video0', () async {
    final svc = V4L2CameraService(device: '/dev/video0');
    final got = Completer<Uint8List>();
    void onFrame() {
      final f = svc.latestFrame.value;
      if (f != null && f.length == V4L2CameraService.frameBytes) {
        if (!got.isCompleted) got.complete(f);
      }
    }

    svc.latestFrame.addListener(onFrame);
    await svc.start();
    final frame = await got.future.timeout(const Duration(seconds: 15));
    // ignore: avoid_print
    print('V4L2_FRAME_OK bytes=${frame.length} '
        'firstPx=${frame[0]},${frame[1]},${frame[2]},${frame[3]}');
    expect(frame.length, V4L2CameraService.frameBytes);
    await svc.stop();
    svc.latestFrame.removeListener(onFrame);
  }, timeout: const Timeout(Duration(seconds: 30)));
}
