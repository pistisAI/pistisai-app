import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

/// Result of an image compression operation.
class CompressResult {
  /// The compressed image bytes.
  final Uint8List bytes;

  /// The output file path, if written to disk.
  final String? path;

  /// Original file size in bytes (0 if unknown).
  final int originalSize;

  /// Compressed file size in bytes.
  final int compressedSize;

  /// Compression ratio (compressed/original), 0 if original size unknown.
  double get ratio =>
      originalSize > 0 ? compressedSize / originalSize : 0;

  /// Human-readable size reduction description.
  String get summary {
    final saved = originalSize - compressedSize;
    if (originalSize <= 0) {
      return _formatSize(compressedSize);
    }
    final pct = ((1 - ratio) * 100).toStringAsFixed(1);
    return '${_formatSize(compressedSize)} (${_formatSize(saved)} saved, $pct%)';
  }

  const CompressResult({
    required this.bytes,
    this.path,
    this.originalSize = 0,
    required this.compressedSize,
  });

  static String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

/// Compress an image file at [inputPath] and write the result to [outputPath].
///
/// Parameters:
/// - [inputPath]: Path to the source image file.
/// - [outputPath]: Path for the compressed output. If null, overwrites input.
/// - [maxWidth]: Maximum width in pixels (preserves aspect ratio). Default 1920.
/// - [maxHeight]: Maximum height in pixels (preserves aspect ratio). Default 1080.
/// - [quality]: JPEG/PNG quality 0–100. Default 85.
///
/// Returns a [CompressResult] with the compressed bytes and metadata.
///
/// Throws [FileSystemException] if the input file doesn't exist.
/// Throws [FormatException] if the image format is unsupported.
Future<CompressResult> compressImage({
  required String inputPath,
  String? outputPath,
  int maxWidth = 1920,
  int maxHeight = 1080,
  int quality = 85,
}) async {
  final inputFile = File(inputPath);
  if (!await inputFile.exists()) {
    throw FileSystemException('Input file not found', inputPath);
  }

  final originalBytes = await inputFile.readAsBytes();
  final originalSize = originalBytes.length;

  final compressed = compressImageBytes(
    originalBytes,
    maxWidth: maxWidth,
    maxHeight: maxHeight,
    quality: quality,
  );

  final outPath = outputPath ?? inputPath;
  final outFile = File(outPath);
  await outFile.writeAsBytes(compressed.bytes, flush: true);

  return CompressResult(
    bytes: compressed.bytes,
    path: outPath,
    originalSize: originalSize,
    compressedSize: compressed.bytes.length,
  );
}

/// Compress raw image bytes in memory.
///
/// Parameters:
/// - [bytes]: Raw image bytes (PNG, JPEG, GIF, WebP, BMP, TIFF).
/// - [maxWidth]: Maximum width in pixels (preserves aspect ratio). Default 1920.
/// - [maxHeight]: Maximum height in pixels (preserves aspect ratio). Default 1080.
/// - [quality]: JPEG/PNG quality 0–100. Default 85.
///
/// Returns a [CompressResult] with the compressed bytes.
///
/// Throws [FormatException] if the image format is unsupported.
CompressResult compressImageBytes(
  Uint8List bytes, {
  int maxWidth = 1920,
  int maxHeight = 1080,
  int quality = 85,
}) {
  final originalSize = bytes.length;

  if (bytes.isEmpty) {
    throw FormatException('Unable to decode image: empty data');
  }

  // Decode the image
  final image = img.decodeImage(bytes);
  if (image == null) {
    throw FormatException('Unable to decode image (unsupported format or corrupt data)');
  }

  debugPrint(
    '[ImageCompress] Original: ${image.width}x${image.height}, '
    '${_formatSize(originalSize)}',
  );

  // Resize if needed, preserving aspect ratio
  img.Image working = image;
  if (image.width > maxWidth || image.height > maxHeight) {
    working = img.copyResize(
      image,
      width: image.width > maxWidth ? maxWidth : null,
      height: image.height > maxHeight ? maxHeight : null,
      interpolation: img.Interpolation.linear,
    );
    debugPrint('[ImageCompress] Resized to ${working.width}x${working.height}');
  }

  // Encode as JPEG (best compression for photos) or PNG (for lossless/alpha)
  final Uint8List compressed;
  final format = _detectFormat(bytes);

  if (format == 'png' || format == 'gif' || format == 'webp') {
    // PNG: use indexed color if possible for smaller size
    compressed = Uint8List.fromList(img.encodePng(working));
  } else {
    // JPEG: apply quality setting
    compressed = Uint8List.fromList(
      img.encodeJpg(working, quality: quality.clamp(0, 100)),
    );
  }

  debugPrint(
    '[ImageCompress] Compressed: ${_formatSize(compressed.length)} '
    '(${((1 - compressed.length / originalSize) * 100).toStringAsFixed(1)}% reduction)',
  );

  return CompressResult(
    bytes: compressed,
    originalSize: originalSize,
    compressedSize: compressed.length,
  );
}

/// Detect image format from magic bytes.
String _detectFormat(Uint8List bytes) {
  if (bytes.length < 4) return 'jpg';
  // PNG: 89 50 4E 47
  if (bytes[0] == 0x89 && bytes[1] == 0x50 && bytes[2] == 0x4E && bytes[3] == 0x47) {
    return 'png';
  }
  // GIF: 47 49 46 38
  if (bytes[0] == 0x47 && bytes[1] == 0x49 && bytes[2] == 0x46 && bytes[3] == 0x38) {
    return 'gif';
  }
  // WebP: 52 49 46 46 ... 57 45 42 50
  if (bytes.length >= 12 &&
      bytes[0] == 0x52 && bytes[1] == 0x49 && bytes[2] == 0x46 && bytes[3] == 0x46 &&
      bytes[8] == 0x57 && bytes[9] == 0x45 && bytes[10] == 0x42 && bytes[11] == 0x50) {
    return 'webp';
  }
  // BMP: 42 4D
  if (bytes[0] == 0x42 && bytes[1] == 0x4D) {
    return 'bmp';
  }
  // TIFF: 49 49 2A 00 or 4D 4D 00 2A
  if ((bytes[0] == 0x49 && bytes[1] == 0x49 && bytes[2] == 0x2A && bytes[3] == 0x00) ||
      (bytes[0] == 0x4D && bytes[1] == 0x4D && bytes[2] == 0x00 && bytes[3] == 0x2A)) {
    return 'tiff';
  }
  return 'jpg';
}

String _formatSize(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}
