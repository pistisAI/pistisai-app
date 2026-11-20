import 'dart:io';
import 'dart:typed_data';

import 'package:sqlite3/common.dart';

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
