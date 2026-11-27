/// Owner-only (0700) folders in shared locations such as `/tmp`.
///
/// A folder with a fixed name in a shared temp directory can be created in
/// advance by another local user, or replaced by a symlink to a folder they
/// control. These helpers refuse such a folder instead of writing into it.
library;

import 'dart:io';

import 'package:flutter/foundation.dart';

/// Permission bits of [path] (`stat` without following links), or null.
int? permissionBits(String path) {
  try {
    final stat = Link(path).statSync();
    if (stat.type == FileSystemEntityType.notFound) return null;
    return stat.mode & 0x1FF;
  } catch (_) {
    return null;
  }
}

int? _currentUid;

int? _uidOfCurrentUser() {
  if (_currentUid != null) return _currentUid;
  try {
    final result = Process.runSync('id', ['-u']);
    if (result.exitCode == 0) {
      _currentUid = int.tryParse(result.stdout.toString().trim());
    }
  } catch (e) {
    debugPrint('[OwnerOnlyDirectory] Could not read the current user id: $e');
  }
  return _currentUid;
}

int? _ownerUid(String path) {
  try {
    final args = Platform.isMacOS ? ['-f', '%u', path] : ['-c', '%u', path];
    final result = Process.runSync('stat', args);
    if (result.exitCode != 0) return null;
    return int.tryParse(result.stdout.toString().trim());
  } catch (e) {
    debugPrint('[OwnerOnlyDirectory] Could not read the folder owner: $e');
    return null;
  }
}

/// True when [path] is a real folder (not a symlink) owned by the current
/// user. On Windows only the folder check applies.
bool isOwnedDirectorySync(String path) {
  final type = FileSystemEntity.typeSync(path, followLinks: false);
  if (type != FileSystemEntityType.directory) return false;
  if (Platform.isWindows) return true;
  final uid = _uidOfCurrentUser();
  return uid != null && _ownerUid(path) == uid;
}

/// True when [path] is a real folder (not a symlink) owned by the current
/// user with mode 0700. Always true for an existing folder on Windows.
bool isOwnerOnlyDirectorySync(String path) {
  if (!isOwnedDirectorySync(path)) return false;
  if (Platform.isWindows) return true;
  return permissionBits(path) == 0x1C0; // 0700
}

/// Creates [path] as an owner-only folder, or tightens an existing one to
/// 0700. Returns false, without writing anything, when [path] is a symlink,
/// is not a folder, is owned by another user, or its mode cannot be set.
///
/// On Windows the folder inherits the ACL of its parent and only the
/// symlink and type checks apply.
bool ensureOwnerOnlyDirectorySync(String path) {
  try {
    var type = FileSystemEntity.typeSync(path, followLinks: false);
    if (type == FileSystemEntityType.notFound) {
      final parent = Directory(path).parent;
      if (!parent.existsSync()) parent.createSync(recursive: true);
      if (Platform.isWindows) {
        Directory(path).createSync();
      } else {
        // mkdir -m sets the mode atomically, so the folder is never readable
        // by others, even briefly. A failure (for example someone created it
        // in between) is handled by the checks below.
        Process.runSync('mkdir', ['-m', '700', path]);
      }
      type = FileSystemEntity.typeSync(path, followLinks: false);
    }
    if (type != FileSystemEntityType.directory) {
      debugPrint('[OwnerOnlyDirectory] Refused (not a real folder): $path');
      return false;
    }
    if (Platform.isWindows) return true;

    final uid = _uidOfCurrentUser();
    if (uid == null || _ownerUid(path) != uid) {
      debugPrint('[OwnerOnlyDirectory] Refused (owned by another user): $path');
      return false;
    }
    if (permissionBits(path) != 0x1C0) {
      final result = Process.runSync('chmod', ['700', path]);
      if (result.exitCode != 0) {
        debugPrint('[OwnerOnlyDirectory] chmod 700 failed: ${result.stderr}');
        return false;
      }
    }
    return isOwnerOnlyDirectorySync(path);
  } catch (e) {
    debugPrint('[OwnerOnlyDirectory] Could not prepare $path: $e');
    return false;
  }
}
