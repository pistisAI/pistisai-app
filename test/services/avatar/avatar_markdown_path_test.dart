import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pistisai/services/avatar/avatar_markdown_path.dart';

void main() {
  group('resolveAvatarMarkdownPath (#1042)', () {
    late Directory home;

    setUp(() {
      home = Directory.systemTemp.createTempSync('pistisai-home-');
    });

    tearDown(() {
      if (home.existsSync()) home.deleteSync(recursive: true);
    });

    test('does not create an OpenClaw folder when none exists', () {
      final path = resolveAvatarMarkdownPath(home.path);
      expect(path, '${home.path}/.openclaw/skills/pistisai');
      expect(Directory(path).existsSync(), isFalse);
      expect(Directory('${home.path}/.openclaw').existsSync(), isFalse);
    });

    test('reuses an existing OpenClaw skill folder', () {
      final existing =
          Directory('${home.path}/.config/openclaw/skills/pistisai')
            ..createSync(recursive: true);
      expect(resolveAvatarMarkdownPath(home.path), existing.path);
    });

    test('without a home folder uses an owner-only temp folder', () {
      final path = resolveAvatarMarkdownPath(null);
      expect(path, isNot(Directory.systemTemp.path));
      expect(path, contains('pistisai-skill'));
      expect(Directory(path).existsSync(), isTrue);
    });
  });
}
