// Paste in the file operations screen must never overwrite an existing item,
// and only reports success once the copy or move really happened
// (AGENTS.md: "Controls tell the truth").
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:pistisai/screens/desktop/file_operations_screen.dart';

void main() {
  late Directory root;
  late Directory source;
  late Directory target;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('file_paste_test_');
    source = await Directory(p.join(root.path, 'source')).create();
    target = await Directory(p.join(root.path, 'target')).create();
  });

  tearDown(() async {
    if (await root.exists()) await root.delete(recursive: true);
  });

  test('copy keeps an existing file with the same name', () async {
    final original = File(p.join(source.path, 'notes.txt'))
      ..writeAsStringSync('new');
    final existing = File(p.join(target.path, 'notes.txt'))
      ..writeAsStringSync('keep me');

    final pasted = await pasteFileSystemEntity(original, target, move: false);

    expect(existing.readAsStringSync(), 'keep me');
    expect(pasted, p.join(target.path, 'notes (1).txt'));
    expect(File(pasted!).readAsStringSync(), 'new');
    expect(original.existsSync(), isTrue);
  });

  test('move keeps an existing file with the same name', () async {
    final original = File(p.join(source.path, 'notes.txt'))
      ..writeAsStringSync('moved');
    final existing = File(p.join(target.path, 'notes.txt'))
      ..writeAsStringSync('keep me');
    File(p.join(target.path, 'notes (1).txt')).writeAsStringSync('also kept');

    final pasted = await pasteFileSystemEntity(original, target, move: true);

    expect(existing.readAsStringSync(), 'keep me');
    expect(pasted, p.join(target.path, 'notes (2).txt'));
    expect(File(pasted!).readAsStringSync(), 'moved');
    expect(original.existsSync(), isFalse);
  });

  test('copy into the same folder makes a copy instead of truncating',
      () async {
    final original = File(p.join(source.path, 'data.csv'))
      ..writeAsStringSync('a,b');

    final pasted = await pasteFileSystemEntity(original, source, move: false);

    expect(original.readAsStringSync(), 'a,b');
    expect(pasted, p.join(source.path, 'data (1).csv'));
    expect(File(pasted!).readAsStringSync(), 'a,b');
  });

  test('copying a folder keeps an existing folder of the same name', () async {
    final folder = await Directory(p.join(source.path, 'docs')).create();
    File(p.join(folder.path, 'a.txt')).writeAsStringSync('from source');
    final existing = await Directory(p.join(target.path, 'docs')).create();
    File(p.join(existing.path, 'a.txt')).writeAsStringSync('keep me');

    final pasted = await pasteFileSystemEntity(folder, target, move: false);

    expect(File(p.join(existing.path, 'a.txt')).readAsStringSync(), 'keep me');
    expect(pasted, p.join(target.path, 'docs (1)'));
    expect(File(p.join(pasted!, 'a.txt')).readAsStringSync(), 'from source');
  });

  test('moving into the folder the item is already in does nothing', () async {
    final original = File(p.join(source.path, 'notes.txt'))
      ..writeAsStringSync('x');

    final pasted = await pasteFileSystemEntity(original, source, move: true);

    expect(pasted, isNull);
    expect(original.readAsStringSync(), 'x');
    expect(source.listSync(), hasLength(1));
  });

  test('refuses to paste a folder inside itself', () async {
    final folder = await Directory(p.join(source.path, 'docs')).create();
    final inner = await Directory(p.join(folder.path, 'inner')).create();

    expect(
      () => pasteFileSystemEntity(folder, inner, move: false),
      throwsA(isA<PasteIntoItselfException>()),
    );
    expect(
      () => pasteFileSystemEntity(folder, folder, move: true),
      throwsA(isA<PasteIntoItselfException>()),
    );
  });

  test('a failed copy throws instead of reporting success', () async {
    final missing = File(p.join(source.path, 'gone.txt'));

    await expectLater(
      pasteFileSystemEntity(missing, target, move: false),
      throwsA(isA<FileSystemException>()),
    );
    expect(target.listSync(), isEmpty);
  });
}
