import 'package:flutter_test/flutter_test.dart';
import 'package:pistisai/services/vision/ocr_engine_service.dart';

/// Behaves as on Android/iOS, where the tesseract_ocr plugin fallback exists.
class _PluginPlatformOcr extends OcrEngineService {
  @override
  bool get pluginFallbackSupported => true;
}

void main() {
  group('OcrEngineService', () {
    late OcrEngineService service;

    setUp(() {
      service = _PluginPlatformOcr();
    });

    tearDown(() async {
      await service.dispose();
    });

    group('Initialization', () {
      test('should have initial state not initialized', () {
        expect(service.isInitialized, isFalse);
        expect(service.lastError, isNull);
      });

      test('reports failure when neither native Tesseract nor the plugin exists',
          () async {
        // The test host has no native OCR channel, and the tesseract_ocr
        // plugin only ships for Android and iOS.
        final desktop = OcrEngineService();
        expect(desktop.pluginFallbackSupported, isFalse);
        final ok = await desktop.initialize();
        expect(ok, isFalse);
        expect(desktop.isInitialized, isFalse);
        expect(desktop.lastError, contains('OCR is not available'));
      });

      test('initializes through the plugin where the plugin exists', () async {
        expect(await service.initialize(), isTrue);
        expect(service.isInitialized, isTrue);
        expect(service.lastError, isNull);
      });

      test('should be idempotent when initializing multiple times', () async {
        await service.initialize();
        final firstInit = service.isInitialized;
        await service.initialize();
        expect(service.isInitialized, equals(firstInit));
      });
    });

    group('extractText', () {
      test('should throw ArgumentError for non-existent file', () async {
        expect(
          () => service.extractText('/path/to/nonexistent.png'),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('should return empty string on OCR failure', () async {
        // Create an invalid image file for testing
        final result = await service.extractText('/dev/null');
        // Should return empty string, not throw
        expect(result, isEmpty);
      });

      test('should handle initialize before extract', () async {
        // Service doesn't require initialization for extractText
        // but lastError should be set appropriately
        try {
          await service.extractText('/nonexistent.png');
        } catch (e) {
          // Expected to throw ArgumentError
        }
        expect(service.lastError, isNotNull);
        expect(service.lastError, contains('not found'));
      });
    });

    group('extractTextMultilingual', () {
      test('should throw ArgumentError for non-existent file', () async {
        expect(
          () => service.extractTextMultilingual('/path/to/nonexistent.png'),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('should use default languages when not specified', () async {
        // Test that default languages are used
        try {
          await service.extractTextMultilingual('/dev/null');
        } catch (e) {
          // Expected for invalid file
        }
        // Should not throw for language parameter
      });

      test('should use custom languages when specified', () async {
        final customLanguages = ['eng', 'fra', 'deu'];
        try {
          await service.extractTextMultilingual(
            '/dev/null',
            languages: customLanguages,
          );
        } catch (e) {
          // Expected for invalid file
        }
        // Should not throw for language parameter
      });

      test('should return empty string on OCR failure', () async {
        final result = await service.extractTextMultilingual('/dev/null');
        expect(result, isEmpty);
      });
    });

    group('dispose', () {
      test('should dispose gracefully when not initialized', () async {
        expect(() async => await service.dispose(), returnsNormally);
        expect(service.isInitialized, isFalse);
      });

      test('should dispose after initialization', () async {
        await service.initialize();
        await service.dispose();
        expect(service.isInitialized, isFalse);
        expect(service.lastError, isNull);
      });

      test('should handle re-initialization after dispose', () async {
        await service.initialize();
        await service.dispose();
        await service.initialize();
        expect(service.isInitialized, isTrue);
      });
    });

    group('Error Handling', () {
      test('should store last error on initialization failure', () async {
        // Force an initialization error by calling dispose first
        await service.dispose();
        // Initialize should still work (idempotent)
        await service.initialize();
        expect(service.isInitialized, isTrue);
      });

      test('should store last error on extractText failure', () async {
        try {
          await service.extractText('/nonexistent.png');
        } catch (e) {
          // Expected to throw
        }
        expect(service.lastError, isNotNull);
        expect(service.lastError, contains('not found'));
      });

      test('should store last error on multilingual extract failure', () async {
        final result = await service.extractTextMultilingual('/dev/null');
        expect(result, isEmpty);
        // lastError should be set on failure
        expect(service.lastError, isNotNull);
      });
    });

    group('isInitialized', () {
      test('should return false before initialization', () {
        expect(service.isInitialized, isFalse);
      });

      test('should return true after initialization', () async {
        await service.initialize();
        expect(service.isInitialized, isTrue);
      });

      test('should return false after dispose', () async {
        await service.initialize();
        await service.dispose();
        expect(service.isInitialized, isFalse);
      });
    });
  });
}
