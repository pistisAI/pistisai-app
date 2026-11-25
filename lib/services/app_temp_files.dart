/// One app-owned temp folder for screenshots, camera frames and TTS audio.
///
/// Every temporary capture the app writes goes under
/// `<temp>/<brand>-captures`, so the local data wipe can delete the whole
/// folder without touching other programs' temp files.
library;

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pistisai/brand/brand.dart';

class AppTempFiles {
  AppTempFiles._();

  /// Name of the app-owned subfolder inside the OS temp folder.
  static String get folderName =>
      '${Brand.current.artifactPrefix.toLowerCase()}-captures';

  /// Replaces the OS temp folder lookup in tests.
  @visibleForTesting
  static Future<Directory> Function()? baseDirectoryOverride;

  static Future<Directory> _baseDirectory() async {
    final override = baseDirectoryOverride;
    if (override != null) return override();
    try {
      return await getTemporaryDirectory();
    } catch (_) {
      return Directory.systemTemp;
    }
  }

  /// The app-owned capture folder (not created).
  static Future<Directory> directory() async {
    final base = await _baseDirectory();
    return Directory('${base.path}${Platform.pathSeparator}$folderName');
  }

  /// A fresh file path in the capture folder; the folder is created.
  static Future<String> newPath(String prefix, String extension) async {
    final dir = await directory();
    await dir.create(recursive: true);
    final stamp = DateTime.now().microsecondsSinceEpoch;
    return '${dir.path}${Platform.pathSeparator}${prefix}_$stamp.$extension';
  }

  /// Deletes [path] if it exists. Never throws.
  static Future<void> deleteQuietly(String? path) async {
    if (path == null) return;
    try {
      final file = File(path);
      if (await file.exists()) await file.delete();
    } catch (e) {
      debugPrint('[AppTempFiles] Could not delete a temp file: $e');
    }
  }

  /// Deletes the whole capture folder.
  static Future<void> deleteAll() async {
    final dir = await directory();
    if (await dir.exists()) await dir.delete(recursive: true);
  }

  /// Paths of files still inside the capture folder.
  static Future<List<String>> listRemaining() async {
    final dir = await directory();
    if (!await dir.exists()) return const <String>[];
    return dir
        .list(recursive: true)
        .where((entity) => entity is File)
        .map((entity) => entity.path)
        .toList();
  }
}
