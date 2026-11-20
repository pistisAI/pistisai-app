import 'dart:io';

import 'package:sqlite3/sqlite3.dart';

import 'local_brain_encryption.dart';

/// Migrates an existing plaintext `local_brain.sqlite` to an encrypted file.
///
/// No-op when the file is missing or already encrypted (non-SQLite header).
/// Uses VACUUM INTO + PRAGMA rekey as recommended by Drift for sqlite3mc.
///
/// Crash-safe: the plaintext file is renamed to `.plaintext-bak` and only
/// deleted once the encrypted copy is in place. A run interrupted at any step
/// is finished on the next start by [_recoverInterruptedMigration], so the
/// data is never left only in a temporary file and no plaintext copy stays
/// behind next to an encrypted database.
///
/// Lives in its own native-only file because the default [sqlite] engine comes
/// from `package:sqlite3/sqlite3.dart`, which imports `dart:ffi`. Keeping it
/// out of the web-reachable encryption helpers avoids pulling FFI
/// into web builds, where encryption is never used (the web database uses
/// WasmDatabase via connection/web.dart).
Future<void> migratePlaintextLocalBrainToEncrypted({
  required File databaseFile,
  required String key,
  CommonSqlite3? sqlite,
}) async {
  final engine = sqlite ?? sqlite3;
  final tmp = File('${databaseFile.path}.encrypt-tmp');
  final backup = File('${databaseFile.path}.plaintext-bak');

  await _recoverInterruptedMigration(databaseFile, tmp, backup);

  if (!await isPlaintextSqliteFile(databaseFile)) {
    return;
  }

  if (await tmp.exists()) {
    await tmp.delete();
  }

  final escapedTmp = escapeSqlString(tmp.path);

  final plaintextDb = engine.open(databaseFile.path);
  try {
    plaintextDb.execute("VACUUM INTO '$escapedTmp';");
  } finally {
    plaintextDb.close();
  }

  final toEncrypt = engine.open(tmp.path);
  try {
    if (!hasCipherSupport(toEncrypt)) {
      throw StateError(
        'Cannot encrypt local_brain.sqlite: cipher support missing in SQLite build.',
      );
    }
    toEncrypt.execute("PRAGMA cipher = 'sqlcipher';");
    toEncrypt.execute("PRAGMA rekey = '${escapeSqlString(key)}';");
  } finally {
    toEncrypt.close();
  }

  // Check the encrypted copy opens with the key before touching the original.
  final check = engine.open(tmp.path);
  try {
    applyLocalBrainEncryption(check, key);
    check.select('SELECT count(*) FROM sqlite_master');
  } finally {
    check.close();
  }

  // The plaintext WAL/SHM must not be replayed against the encrypted file.
  // VACUUM INTO above already copied every committed page.
  await _deleteSqliteSidecars(databaseFile);
  if (await backup.exists()) {
    await backup.delete();
  }
  await databaseFile.rename(backup.path);
  await tmp.rename(databaseFile.path);
  await backup.delete();
}

/// Finishes a migration that stopped part-way (crash, power loss).
Future<void> _recoverInterruptedMigration(
  File databaseFile,
  File tmp,
  File backup,
) async {
  final hasDb = await databaseFile.exists();
  if (!hasDb) {
    if (await tmp.exists() && !await isPlaintextSqliteFile(tmp)) {
      // Stopped between the two renames: the encrypted copy is complete.
      await tmp.rename(databaseFile.path);
    } else if (await backup.exists()) {
      // Encrypted copy missing: put the original back and migrate again.
      await backup.rename(databaseFile.path);
      return;
    }
  }
  if (await databaseFile.exists() &&
      !await isPlaintextSqliteFile(databaseFile) &&
      await backup.exists()) {
    // Stopped before the plaintext backup was deleted.
    await backup.delete();
  }
}

Future<void> _deleteSqliteSidecars(File databaseFile) async {
  for (final suffix in ['-wal', '-shm']) {
    final side = File('${databaseFile.path}$suffix');
    if (await side.exists()) {
      await side.delete();
    }
  }
}
