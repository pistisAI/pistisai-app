import 'dart:io';

import 'voice/cloud_tts_service.dart';

/// Files this app writes only to reuse or serve them again, which are safe
/// to delete at any time. Today that is the generated speech audio.
///
/// "Clear cache" must delete something real and report what it freed, so
/// this is the single place that knows where those files live.
class AppCacheService {
  AppCacheService({List<Directory>? directories})
      : _directories = directories ?? [defaultSpeechCacheDirectory()];

  final List<Directory> _directories;

  /// Same location as `CloudTtsService`'s default output directory; the
  /// path is computed by that class so the two can never disagree.
  static Directory defaultSpeechCacheDirectory() {
    return Directory(CloudTtsService.defaultCacheDirectory(
      Platform.environment,
      tempDirectory: Directory.systemTemp.path,
    ));
  }

  /// Total size of the cached files, in bytes.
  Future<int> sizeInBytes() async {
    var total = 0;
    await for (final file in _files()) {
      try {
        total += await file.length();
      } on FileSystemException {
        // Removed while listing; it no longer takes space.
      }
    }
    return total;
  }

  /// Deletes the cached files and returns the bytes actually freed. A file
  /// that cannot be deleted is left in place and not counted.
  Future<int> clear() async {
    var freed = 0;
    await for (final file in _files()) {
      try {
        final size = await file.length();
        await file.delete();
        freed += size;
      } on FileSystemException {
        // In use or already gone.
      }
    }
    return freed;
  }

  Stream<File> _files() async* {
    for (final directory in _directories) {
      if (!await directory.exists()) continue;
      try {
        await for (final entity
            in directory.list(recursive: true, followLinks: false)) {
          if (entity is File) yield entity;
        }
      } on FileSystemException {
        // Unreadable directory: nothing to report from it.
      }
    }
  }

  /// "0 MB", "< 0.1 MB", "1.5 MB", "12 MB" ([unit] lets a translation say "Mo").
  static String formatMegabytes(int bytes, {String unit = 'MB'}) {
    final mb = bytes / (1024 * 1024);
    if (bytes == 0) return '0 $unit';
    if (mb < 10) return '${mb < 0.1 ? '< 0.1' : mb.toStringAsFixed(1)} $unit';
    return '${mb.round()} $unit';
  }
}
