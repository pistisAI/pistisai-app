/// One app-owned temp folder for screenshots, camera frames and TTS audio.
///
/// Every temporary capture the app writes goes under
/// `<temp>/<brand>-captures`, so the local data wipe can delete the whole
/// folder without touching other programs' temp files. The folder is
/// owner-only (0700 on POSIX) so other local users cannot read captures.
library;

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pistisai/brand/brand.dart';
import 'package:pistisai/utils/owner_only_directory.dart';

class AppTempFiles {
  AppTempFiles._();

  /// Name of the app-owned subfolder inside the OS temp folder.
  static String get folderName =>
      '${Brand.current.artifactPrefix.toLowerCase()}-captures';

  /// Replaces the OS temp folder lookup in tests.
  @visibleForTesting
  static Future<Directory> Function()? baseDirectoryOverride;

  /// Replaces the app support folder lookup (the fallback) in tests.
  @visibleForTesting
  static Future<Directory> Function()? fallbackBaseDirectoryOverride;

  static Future<Directory> _baseDirectory() async {
    final override = baseDirectoryOverride;
    if (override != null) return override();
    try {
      return await getTemporaryDirectory();
    } catch (_) {
      return Directory.systemTemp;
    }
  }

  static Future<Directory?> _fallbackBaseDirectory() async {
    final override = fallbackBaseDirectoryOverride;
    if (override != null) return override();
    try {
      return await getApplicationSupportDirectory();
    } catch (_) {
      return null;
    }
  }

  static String _join(Directory base) =>
      '${base.path}${Platform.pathSeparator}$folderName';

  /// Both places the capture folder can live: the OS temp folder first, the
  /// app support folder when the temp one cannot be used safely.
  static Future<List<String>> _candidates() async {
    final fallback = await _fallbackBaseDirectory();
    return [
      _join(await _baseDirectory()),
      if (fallback != null) _join(fallback),
    ];
  }

  /// The owner-only capture folder in use; created if needed.
  ///
  /// The temp location is refused when it is a symlink or owned by another
  /// user (a shared `/tmp` can be pre-created by others); the app support
  /// folder is used instead. On POSIX the folder is mode 0700, so captures
  /// inside it are not readable by other local users.
  static Future<Directory> directory() async {
    final candidates = await _candidates();
    for (final path in candidates) {
      if (ensureOwnerOnlyDirectorySync(path)) return Directory(path);
    }
    throw FileSystemException(
      'No owner-only folder available for temporary captures',
      candidates.first,
    );
  }

  /// A fresh file path in the capture folder; the folder is created.
  static Future<String> newPath(String prefix, String extension) async {
    final dir = await directory();
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

  /// Deletes the capture folder in every location this app uses. A folder
  /// that is a symlink or owned by another user is left alone.
  static Future<void> deleteAll() async {
    for (final path in await _candidates()) {
      if (isOwnedDirectorySync(path)) {
        await Directory(path).delete(recursive: true);
      }
    }
  }

  /// Paths of files still inside the capture folder(s).
  static Future<List<String>> listRemaining() async {
    final remaining = <String>[];
    for (final path in await _candidates()) {
      if (!isOwnedDirectorySync(path)) continue;
      remaining.addAll(await Directory(path)
          .list(recursive: true)
          .where((entity) => entity is File)
          .map((entity) => entity.path)
          .toList());
    }
    return remaining;
  }
}
