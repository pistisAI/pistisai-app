import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pistisai/services/vision/camera_capture_service.dart';
import 'package:pistisai/services/vision/presence_service.dart';

/// In-memory fake of [CameraCaptureService] that does not touch a real device.
class FakeCameraCaptureService extends CameraCaptureService {
  bool _initialized = false;
  final bool _shouldSucceed = true;
  String? _capturedPath;

  @override
  bool get isInitialized => _initialized;

  @override
  String? get lastError => _initialized ? null : 'fake not initialized';

  @override
  Future<void> initialize() async {
    _initialized = true;
  }

  @override
  Future<String?> captureImage() async {
    if (!_shouldSucceed) return null;
    _capturedPath = '${Directory.systemTemp.path}/presence_fake.png';
    return _capturedPath;
  }

  @override
  Future<void> dispose() async {
    _initialized = false;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PresenceService', () {
    late FakeCameraCaptureService fakeCamera;
    late PresenceService service;

    setUp(() {
      fakeCamera = FakeCameraCaptureService();
      service = PresenceService(cameraCaptureService: fakeCamera);
    });

    tearDown(() async {
      await service.disable();
    });

    group('Consent gate', () {
      test('checkNow throws StateError before enable()', () {
        expect(service.isEnabled, isFalse);
        expect(
          () => service.checkNow(),
          throwsA(isA<StateError>()),
        );
      });

      test('enable() flips isEnabled and is idempotent', () async {
        expect(await service.enable(), isTrue);
        expect(service.isEnabled, isTrue);
        expect(await service.enable(), isTrue);
      });
    });

    group('checkNow', () {
      test('returns true and records a check after enable()', () async {
        await service.enable();
        final present = await service.checkNow();
        expect(present, isTrue);
        expect(service.isPresent, isTrue);
        expect(service.lastCheck, isNotNull);
      });

      test('deletes the captured frame immediately', () async {
        await service.enable();
        await service.checkNow();
        if (fakeCamera._capturedPath != null) {
          final stillThere = await File(fakeCamera._capturedPath!).exists();
          expect(stillThere, isFalse);
        }
      });

      test('disable() resets state and releases the camera', () async {
        await service.enable();
        await service.checkNow();
        await service.disable();
        expect(service.isEnabled, isFalse);
        expect(service.isPresent, isFalse);
        expect(service.lastCheck, isNull);
        expect(fakeCamera.isInitialized, isFalse);
      });
    });
  });
}
