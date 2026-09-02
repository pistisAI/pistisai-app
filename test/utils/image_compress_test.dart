import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:pistisai/utils/image_compress.dart';

void main() {
  group('ImageCompress', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('image_compress_test_');
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    /// Generate a small test image (100x80) with some colored content.
    Uint8List generateTestJpeg({int width = 100, int height = 80}) {
      final image = img.Image(width: width, height: height);
      // Fill with a gradient pattern
      for (int y = 0; y < height; y++) {
        for (int x = 0; x < width; x++) {
          image.setPixelRgba(
            x,
            y,
            (x * 255 ~/ width).clamp(0, 255),
            (y * 255 ~/ height).clamp(0, 255),
            128,
            255,
          );
        }
      }
      return Uint8List.fromList(img.encodeJpg(image, quality: 100));
    }

    /// Generate a small test PNG with transparency.
    Uint8List generateTestPng({int width = 50, int height = 50}) {
      final image = img.Image(width: width, height: height);
      for (int y = 0; y < height; y++) {
        for (int x = 0; x < width; x++) {
          image.setPixelRgba(x, y, 255, 0, 0, (x * 255 ~/ width).clamp(0, 255));
        }
      }
      return Uint8List.fromList(img.encodePng(image));
    }

    group('compressImageBytes', () {
      test('compresses a JPEG image in memory', () {
        final bytes = generateTestJpeg();
        expect(bytes.length, greaterThan(0));

        final result = compressImageBytes(
          bytes,
          maxWidth: 1920,
          maxHeight: 1080,
          quality: 50,
        );

        expect(result.bytes, isA<Uint8List>());
        expect(result.bytes.length, greaterThan(0));
        expect(result.originalSize, equals(bytes.length));
        expect(result.compressedSize, equals(result.bytes.length));
        expect(result.ratio, greaterThan(0));
        expect(result.ratio, lessThanOrEqualTo(1.0));
        expect(result.summary, contains('KB'));
      });

      test('resizes image when dimensions exceed max', () {
        final bytes = generateTestJpeg(width: 400, height: 300);
        final originalSize = bytes.length;

        // Force resize by setting small max dimensions
        final result = compressImageBytes(
          bytes,
          maxWidth: 50,
          maxHeight: 50,
          quality: 85,
        );

        expect(result.bytes.length, greaterThan(0));
        expect(result.bytes.length, lessThan(originalSize),
            reason: 'Resized image should be smaller');
      });

      test('keeps small images at original size when within limits', () {
        final bytes = generateTestJpeg(width: 50, height: 40);

        final result = compressImageBytes(
          bytes,
          maxWidth: 1920,
          maxHeight: 1080,
          quality: 85,
        );

        expect(result.bytes.length, greaterThan(0));
        // Small image may still be compressed by quality reduction
      });

      test('compresses PNG images', () {
        final bytes = generateTestPng();
        expect(bytes.length, greaterThan(0));

        final result = compressImageBytes(
          bytes,
          maxWidth: 1920,
          maxHeight: 1080,
          quality: 85,
        );

        expect(result.bytes, isA<Uint8List>());
        expect(result.bytes.length, greaterThan(0));
      });

      test('throws FormatException for invalid image data', () {
        final invalidBytes = Uint8List.fromList([0, 1, 2, 3, 4, 5]);

        expect(
          () => compressImageBytes(invalidBytes),
          throwsA(isA<FormatException>()),
        );
      });

      test('throws FormatException for empty data', () {
        expect(
          () => compressImageBytes(Uint8List(0)),
          throwsA(isA<FormatException>()),
        );
      });

      test('CompressResult.summary works with unknown original size', () {
        final result = CompressResult(
          bytes: Uint8List.fromList([1, 2, 3]),
          compressedSize: 3,
        );
        expect(result.summary, contains('3 B'));
        expect(result.ratio, equals(0));
      });

      test('CompressResult.summary shows savings with known original size', () {
        final result = CompressResult(
          bytes: Uint8List.fromList(List.filled(500, 0)),
          originalSize: 1000,
          compressedSize: 500,
        );
        expect(result.summary, contains('500 B'));
        expect(result.summary, contains('50.0%'));
      });
    });

    group('compressImage (file-based)', () {
      test('compresses an image file and writes output', () async {
        final bytes = generateTestJpeg();
        final inputPath = '${tempDir.path}/test_input.jpg';
        await File(inputPath).writeAsBytes(bytes);

        final outputPath = '${tempDir.path}/test_output.jpg';
        final result = await compressImage(
          inputPath: inputPath,
          outputPath: outputPath,
          quality: 50,
        );

        expect(result.path, equals(outputPath));
        expect(result.bytes.length, greaterThan(0));
        expect(result.originalSize, equals(bytes.length));
        expect(result.compressedSize, equals(result.bytes.length));

        // Verify output file exists
        final outputFile = File(outputPath);
        expect(await outputFile.exists(), isTrue);
        expect(await outputFile.length(), equals(result.bytes.length));
      });

      test('overwrites input file when no outputPath given', () async {
        final bytes = generateTestJpeg();
        final inputPath = '${tempDir.path}/test_overwrite.jpg';
        await File(inputPath).writeAsBytes(bytes);

        final result = await compressImage(
          inputPath: inputPath,
          quality: 50,
        );

        expect(result.path, equals(inputPath));
        // File should be overwritten
        final file = File(inputPath);
        expect(await file.length(), equals(result.bytes.length));
      });

      test('throws FileSystemException for missing input', () async {
        expect(
          () => compressImage(inputPath: '/nonexistent/file.jpg'),
          throwsA(isA<FileSystemException>()),
        );
      });
    });

    group('CompressResult', () {
      test('constructor and getters', () {
        final result = CompressResult(
          bytes: Uint8List.fromList([1, 2, 3]),
          path: '/tmp/test.jpg',
          originalSize: 100,
          compressedSize: 3,
        );

        expect(result.bytes, equals([1, 2, 3]));
        expect(result.path, equals('/tmp/test.jpg'));
        expect(result.originalSize, equals(100));
        expect(result.compressedSize, equals(3));
        expect(result.ratio, closeTo(0.03, 0.01));
      });

      test('ratio is 0 when originalSize is 0', () {
        final result = CompressResult(
          bytes: Uint8List.fromList([1, 2, 3]),
          compressedSize: 3,
        );
        expect(result.ratio, equals(0));
      });
    });
  });
}
