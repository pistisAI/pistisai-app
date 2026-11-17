import 'dart:io';
import 'dart:typed_data';

import 'package:sqlite3/common.dart';
import 'package:sqlite3/sqlite3.dart';

/// Helpers for SQLCipher-compatible AES-256 encryption of `local_brain.sqlite`
/// via SQLite3MultipleCiphers (`sqlite3` package with `source: sqlite3mc`).

/// Escape a string for use inside a single-quoted SQL literal.
String escapeSqlString(String source) => source.replaceAll("'", "''");

/// True when the linked SQLite build exposes MultipleCiphers / SQLCipher APIs.
bool hasCipherSupport(CommonDatabase database) {
  try {
    return database.select('PRAGMA cipher;').isNotEmpty;
  } catch (_) {
    return false;
  }
}

/// Apply SQLCipher-compatible AES-256 cipher + key before any other SQL.
///
/// Must run before Drift touches the connection. Throws if the bundled SQLite
/// build lacks encryption support (wrong hook / plain sqlite3).
void applyLocalBrainEncryption(CommonDatabase database, String key) {
  if (!hasCipherSupport(database)) {
    throw StateError(
      'local_brain.sqlite encryption requires SQLite3MultipleCiphers '
      '(pubspec hooks: sqlite3.source = sqlite3mc). Cipher support is missing.',
    );
  }
  // SQLCipher mode → AES-256-CBC with SQLCipher key derivation.
  database.execute("PRAGMA cipher = 'sqlcipher';");
  database.execute("PRAGMA key = '${escapeSqlString(key)}';");
}

/// SQLite plaintext databases begin with this 16-byte header.
const List<int> sqlitePlaintextHeader = [
  0x53, // S
  0x51, // Q
  0x4c, // L
  0x69, // i
  0x74, // t
  0x65, // e
  0x20, //
  0x66, // f
  0x6f, // o
  0x72, // r
  0x6d, // m
  0x61, // a
  0x74, // t
  0x20, //
  0x33, // 3
  0x00,
];

/// Returns true if [file] exists and starts with the unencrypted SQLite header.
Future<bool> isPlaintextSqliteFile(File file) async {
  if (!await file.exists()) return false;
  final raf = await file.open(mode: FileMode.read);
  try {
    final header = await raf.read(sqlitePlaintextHeader.length);
    if (header.length < sqlitePlaintextHeader.length) return false;
    for (var i = 0; i < sqlitePlaintextHeader.length; i++) {
      if (header[i] != sqlitePlaintextHeader[i]) return false;
    }
    return true;
  } finally {
    await raf.close();
  }
}

/// Returns true if [bytes] look like an unencrypted SQLite database header.
bool looksLikePlaintextSqlite(Uint8List bytes) {
  if (bytes.length < sqlitePlaintextHeader.length) return false;
  for (var i = 0; i < sqlitePlaintextHeader.length; i++) {
    if (bytes[i] != sqlitePlaintextHeader[i]) return false;
  }
  return true;
}

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
