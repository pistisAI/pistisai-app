/// Where [MarkdownSyncService] writes the avatar Markdown files.
library;

import 'dart:io';

import 'package:pistisai/utils/owner_only_directory.dart';

/// Returns the folder for `personality.md`, `memory.md` and `context.md`.
///
/// An existing OpenClaw skill folder is reused. Otherwise the default
/// OpenClaw path is returned **without creating it**: the folder is made
/// only when a Markdown file is first written, so a Hermes-only install
/// does not get an OpenClaw folder at startup (#1042).
///
/// Without a home directory the files go to an owner-only folder inside the
/// system temp directory, never temp itself; a pre-created or symlinked
/// folder is refused in favour of a fresh private temp folder.
String resolveAvatarMarkdownPath(String? home) {
  if (home == null) {
    final fallback = '${Directory.systemTemp.path}/pistisai-skill';
    if (ensureOwnerOnlyDirectorySync(fallback)) return fallback;
    return Directory.systemTemp.createTempSync('pistisai-skill-').path;
  }

  final possiblePaths = [
    '$home/.openclaw/skills/pistisai',
    '$home/.config/openclaw/skills/pistisai',
    '$home/AppData/Roaming/openclaw/skills/pistisai', // Windows
  ];

  for (final path in possiblePaths) {
    if (Directory(path).existsSync()) {
      return path;
    }
  }

  return possiblePaths.first;
}
