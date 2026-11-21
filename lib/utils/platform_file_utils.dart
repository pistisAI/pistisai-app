import 'dart:io';

import 'package:flutter/foundation.dart';

// Desktop implementation for file utilities
class PlatformFileUtils {
  /// Older builds wrote OAuth callback URLs (auth code included) here, with
  /// default permissions.
  static String get staleCallbackFilePath =>
      '${Directory.systemTemp.path}${Platform.pathSeparator}pistisai_callback.txt';

  /// No-op: OAuth callback URLs (including auth codes) must not be written to
  /// a world-readable temp file. Deep-link handling uses the in-process URL.
  static Future<void> writeCallbackFile(String callbackUrl) async {}

  /// Deletes the callback file older builds left in the temp folder.
  static Future<void> deleteStaleCallbackFile() async {
    try {
      final file = File(staleCallbackFilePath);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      debugPrint(
          '[PlatformFileUtils] Could not delete stale callback file: $e');
    }
  }
}
