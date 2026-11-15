import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pistisai/database/local_brain_encryption.dart';
import 'package:pistisai/database/local_brain_key_store.dart';
import 'package:sqlite3/sqlite3.dart';

class _MemoryVault implements LocalBrainKeyVault {
  final Map<String, String> store = {};

  @override
  Future<String?> read(String key) async => store[key];

  @override
  Future<void> write(String key, String value) async {
    store[key] = value;
  }
}

void main() {
  group('escapeSqlString', () {
    test('escapes single quotes', () {
      expect(escapeSqlString("a'b"), "a''b");
      expect(escapeSqlString('plain'), 'plain');
    });
  });

  group('looksLikePlaintextSqlite', () {
    test('detects SQLite header', () {
      expect(
        looksLikePlaintextSqlite(
          Uint8List.fromList(sqlitePlaintextHeader),
        ),
        isTrue,
      );
      expect(
        looksLikePlaintextSqlite(Uint8List.fromList(List.filled(16, 0))),
        isFalse,
      );
    });
  });

  group('LocalBrainKeyStore', () {
    test('prefers environment variable over keystore', () async {
      final vault = _MemoryVault();
      vault.store[LocalBrainKeyStore.secureStorageKey] = 'keystore-key';
      final store = LocalBrainKeyStore(
        vault: vault,
        environment: {LocalBrainKeyStore.envVarName: 'env-secret'},
      );
      expect(await store.resolveKey(), 'env-secret');
    });

    test('reads existing keystore key when env unset', () async {
      final vault = _MemoryVault();
      vault.store[LocalBrainKeyStore.secureStorageKey] = 'from-keystore';
      final store = LocalBrainKeyStore(
        vault: vault,
        environment: const {},
      );
      expect(await store.resolveKey(), 'from-keystore');
    });

    test('generates and persists a key when none exists', () async {
      final vault = _MemoryVault();
      final store = LocalBrainKeyStore(
        vault: vault,
        environment: const {},
      );
      final key = await store.resolveKey();
      expect(key, isNotEmpty);
      expect(vault.store[LocalBrainKeyStore.secureStorageKey], key);
      expect(await store.resolveKey(), key);
    });

    test('never embeds a default passphrase from config', () {
      expect(LocalBrainKeyStore.envVarName, 'PISTISAI_LOCAL_BRAIN_KEY');
      expect(
        LocalBrainKeyStore.secureStorageKey,
        'local_brain_encryption_key',
      );
    });
  });

  group('SQLCipher-compatible encryption (sqlite3mc)', () {
    late Directory tmpDir;

    setUp(() async {
      tmpDir = await Directory.systemTemp.createTemp('local_brain_enc_');
    });

    tearDown(() async {
      if (await tmpDir.exists()) {
        await tmpDir.delete(recursive: true);
      }
    });

    test('cipher support is present with sqlite3mc hook', () {
      final db = sqlite3.openInMemory();
      addTearDown(db.close);
      expect(
        hasCipherSupport(db),
        isTrue,
        reason: 'pubspec hooks must set sqlite3.source to sqlite3mc',
      );
    });

    test('encrypted file loses SQLite plaintext header', () async {
      final file = File('${tmpDir.path}/local_brain.sqlite');
      const key = 'test-passphrase-aes256';

      final db = sqlite3.open(file.path);
      try {
        applyLocalBrainEncryption(db, key);
        db.execute('CREATE TABLE t (id INTEGER PRIMARY KEY, note TEXT);');
        db.execute("INSERT INTO t (note) VALUES ('secret-memory');");
      } finally {
        db.close();
      }

      expect(await isPlaintextSqliteFile(file), isFalse);
      final bytes = await file.readAsBytes();
      expect(looksLikePlaintextSqlite(bytes), isFalse);
      expect(
        String.fromCharCodes(bytes),
        isNot(contains('secret-memory')),
      );

      final reopen = sqlite3.open(file.path);
      try {
        applyLocalBrainEncryption(reopen, key);
        final rows = reopen.select('SELECT note FROM t');
        expect(rows.single['note'], 'secret-memory');
      } finally {
        reopen.close();
      }
    });

    test('migrates existing plaintext database in place', () async {
      final file = File('${tmpDir.path}/local_brain.sqlite');
      const key = 'migrate-key';

      final plain = sqlite3.open(file.path);
      try {
        plain.execute('CREATE TABLE mem (body TEXT);');
        plain.execute("INSERT INTO mem VALUES ('plain-then-encrypted');");
      } finally {
        plain.close();
      }
      expect(await isPlaintextSqliteFile(file), isTrue);

      await migratePlaintextLocalBrainToEncrypted(
        databaseFile: file,
        key: key,
      );

      expect(await isPlaintextSqliteFile(file), isFalse);

      final encrypted = sqlite3.open(file.path);
      try {
        applyLocalBrainEncryption(encrypted, key);
        final rows = encrypted.select('SELECT body FROM mem');
        expect(rows.single['body'], 'plain-then-encrypted');
      } finally {
        encrypted.close();
      }
    });
  });
}
