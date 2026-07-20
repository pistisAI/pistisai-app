import 'package:camera/camera.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('camera enumerates on this Linux host', () async {
    final cameras = await availableCameras();
    // ignore: avoid_print
    print('CAMERAS_FOUND: ${cameras.length}');
    for (final c in cameras) {
      // ignore: avoid_print
      print('  - ${c.name} | ${c.lensDirection} | ${c.sensorOrientation}');
    }
    expect(cameras.length, greaterThanOrEqualTo(1),
        reason: 'expected at least one camera from /dev/video*');
  });
}
