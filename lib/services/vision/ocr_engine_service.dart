import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:tesseract_ocr/tesseract_ocr.dart';
import 'package:tesseract_ocr/ocr_engine_config.dart';

/// OCR Engine Service
///
/// This service handles optical character recognition (OCR) functionality.
/// It extracts text from images including screenshots and camera frames.
/// On desktop platforms (Linux/Windows), it delegates to native platform
/// channels for Tesseract integration, with the tesseract_ocr plugin as fallback.
class OcrEngineService {
  static const MethodChannel _channel =
      MethodChannel('pistisai/ocr_engine');

  bool _isInitialized = false;
  String? _lastError;

  /// Indicates whether the service has been initialized
  bool get isInitialized => _isInitialized;

  /// The last error that occurred (null if no error)
  String? get lastError => _lastError;

  /// Initialize the OCR engine
  ///
  /// Uses the native Tesseract integration when the platform channel reports
  /// it ready. Otherwise falls back to the tesseract_ocr plugin, which only
  /// ships for Android and iOS. Returns true when one of the two is usable;
  /// otherwise returns false and leaves the reason in [lastError].
  /// Calling it again after a success has no effect.
  Future<bool> initialize() async {
    if (_isInitialized) {
      debugPrint('[OCR] Already initialized, skipping');
      return true;
    }

    debugPrint('[OCR] Initializing Tesseract OCR...');

    // On web, OCR is not supported
    if (kIsWeb) {
      _lastError = 'OCR not supported on web platform';
      debugPrint('[OCR] $_lastError');
      return false;
    }

    String nativeReason;
    try {
      // Try native platform channel first (desktop)
      final nativeResult = await _channel.invokeMethod('ocrInitialize');
      if (nativeResult == true) {
        debugPrint('[OCR] Native Tesseract integration initialized');
        _isInitialized = true;
        _lastError = null;
        return true;
      }
      nativeReason = 'native Tesseract is not ready';
    } catch (e) {
      nativeReason = 'native Tesseract is not available ($e)';
    }

    // Plugin fallback: the tesseract_ocr plugin runs Tesseract on first use,
    // but it only exists on Android and iOS.
    if (pluginFallbackSupported) {
      _isInitialized = true;
      _lastError = null;
      debugPrint('[OCR] Initialized (plugin mode)');
      return true;
    }

    _isInitialized = false;
    _lastError = 'OCR is not available on this device: $nativeReason, '
        'and the Tesseract plugin only runs on Android and iOS';
    debugPrint('[OCR] $_lastError');
    return false;
  }

  /// Whether the tesseract_ocr plugin fallback exists on this platform.
  @visibleForTesting
  bool get pluginFallbackSupported =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  /// Extract text from an image file
  ///
  /// [imagePath] is the path to the image file (PNG, JPG, etc.)
  /// Returns the extracted text as a trimmed string, or empty string on failure.
  ///
  /// Throws [ArgumentError] if the image file doesn't exist.
  Future<String> extractText(String imagePath) async {
    if (!File(imagePath).existsSync()) {
      final error = 'Image file not found: $imagePath';
      _lastError = error;
      debugPrint('[OCR] $error');
      throw ArgumentError(error);
    }

    debugPrint('[OCR] Extracting text from: $imagePath');

    // Try native platform channel first (desktop)
    if (!kIsWeb) {
      try {
        final nativeResult = await _channel.invokeMethod('ocrExtractText', {
          'imagePath': imagePath,
        });
        if (nativeResult is String && nativeResult.isNotEmpty) {
          debugPrint('[OCR] Extracted ${nativeResult.length} characters (native)');
          _lastError = null;
          return nativeResult.trim();
        }
      } catch (e) {
        debugPrint('[OCR] Native extraction failed, falling back to plugin: $e');
      }
    }

    try {
      final config = OCRConfig(language: 'eng');
      final text = await TesseractOcr.extractText(imagePath, config: config);
      final result = text.trim();
      debugPrint('[OCR] Extracted ${result.length} characters');
      _lastError = null;
      return result;
    } catch (e) {
      _lastError = 'OCR extraction failed: $e';
      debugPrint('[OCR] $_lastError');
      return '';
    }
  }

  /// Extract text with multiple languages
  ///
  /// [imagePath] is the path to the image file
  /// [languages] is the list of languages to use (default: ['eng', 'chi_sim'])
  /// Returns the extracted text as a trimmed string, or empty string on failure.
  ///
  /// Throws [ArgumentError] if the image file doesn't exist.
  ///
  /// Language codes follow ISO 639-3 standard:
  /// - 'eng' for English
  /// - 'chi_sim' for Simplified Chinese
  /// - 'fra' for French
  /// - 'deu' for German
  /// - 'spa' for Spanish
  /// - etc.
  Future<String> extractTextMultilingual(
    String imagePath, {
    List<String> languages = const ['eng', 'chi_sim'],
  }) async {
    if (!File(imagePath).existsSync()) {
      final error = 'Image file not found: $imagePath';
      _lastError = error;
      debugPrint('[OCR] $error');
      throw ArgumentError(error);
    }

    final langString = languages.join('+');
    debugPrint('[OCR] Extracting text with languages: $langString');

    // Try native platform channel first (desktop)
    if (!kIsWeb) {
      try {
        final nativeResult = await _channel.invokeMethod(
          'ocrExtractTextMultilingual',
          {
            'imagePath': imagePath,
            'languages': languages,
          },
        );
        if (nativeResult is String && nativeResult.isNotEmpty) {
          debugPrint(
              '[OCR] Extracted ${nativeResult.length} characters (native)');
          _lastError = null;
          return nativeResult.trim();
        }
      } catch (e) {
        debugPrint(
            '[OCR] Native multilingual extraction failed, falling back: $e');
      }
    }

    try {
      final config = OCRConfig(language: langString);
      final text = await TesseractOcr.extractText(imagePath, config: config);
      final result = text.trim();
      debugPrint('[OCR] Extracted ${result.length} characters');
      _lastError = null;
      return result;
    } catch (e) {
      _lastError = 'Multilingual OCR extraction failed: $e';
      debugPrint('[OCR] $_lastError');
      return '';
    }
  }

  /// Dispose of the OCR engine
  ///
  /// Releases OCR resources and resets state.
  Future<void> dispose() async {
    if (!_isInitialized) {
      return;
    }

    debugPrint('[OCR] Disposing...');

    // Notify native channel
    if (!kIsWeb) {
      try {
        await _channel.invokeMethod('ocrDispose');
      } catch (e) {
        debugPrint('[OCR] Native dispose failed: $e');
      }
    }

    _isInitialized = false;
    _lastError = null;

    debugPrint('[OCR] Disposed successfully');
  }
}
