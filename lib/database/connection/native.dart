import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/common.dart';

import '../local_brain_encryption.dart';
import '../local_brain_key_store.dart';

/// Opens a native SQLite connection (Linux, Windows, Android, iOS, macOS)
/// with SQLCipher-compatible AES-256 encryption at rest.
QueryExecutor openConnection({
  LocalBrainKeyStore? keyStore,
  Future<Directory> Function()? supportDirectory,
}) {
  return LazyDatabase(() async {
    final dbFolder =
        await (supportDirectory?.call() ?? getApplicationSupportDirectory());
    final file = File(p.join(dbFolder.path, 'local_brain.sqlite'));
    final key = await (keyStore ?? LocalBrainKeyStore()).resolveKey();

    await migratePlaintextLocalBrainToEncrypted(
      databaseFile: file,
      key: key,
    );

    return NativeDatabase(
      file,
      setup: (CommonDatabase db) {
        applyLocalBrainEncryption(db, key);
        db.execute('PRAGMA journal_mode = WAL;');
        db.execute('PRAGMA synchronous = NORMAL;');
        db.execute('PRAGMA temp_store = MEMORY;');
        db.execute('PRAGMA cache_size = -65536;'); // 64MB Cache
      },
    );
  });
}
