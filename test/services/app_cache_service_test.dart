import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:pistisai/services/app_cache_service.dart';

void main() {
  late Directory temp;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('app_cache_test');
  });

  tearDown(() async {
    if (await temp.exists()) await temp.delete(recursive: true);
  });

  test('reports the size of cached files and deletes them', () async {
    await File(p.join(temp.path, 'speech_1.mp3')).writeAsBytes(List.filled(10, 0));
    await Directory(p.join(temp.path, 'sub')).create();
    await File(p.join(temp.path, 'sub', 'speech_2.mp3'))
        .writeAsBytes(List.filled(5, 0));
    final cache = AppCacheService(directories: [temp]);

    expect(await cache.sizeInBytes(), 15);
    expect(await cache.clear(), 15);
    expect(await cache.sizeInBytes(), 0);
    expect(await File(p.join(temp.path, 'speech_1.mp3')).exists(), isFalse);
  });

  test('a missing directory is an empty cache', () async {
    final cache = AppCacheService(
      directories: [Directory(p.join(temp.path, 'does-not-exist'))],
    );

    expect(await cache.sizeInBytes(), 0);
    expect(await cache.clear(), 0);
  });

  test('does not touch files outside its directories', () async {
    final cacheDir = await Directory(p.join(temp.path, 'cache')).create();
    final other = File(p.join(temp.path, 'keep.txt'));
    await other.writeAsString('keep');
    await File(p.join(cacheDir.path, 'a')).writeAsString('x');

    await AppCacheService(directories: [cacheDir]).clear();

    expect(await other.exists(), isTrue);
  });

  test('formats sizes', () {
    expect(AppCacheService.formatMegabytes(0), '0 MB');
    expect(AppCacheService.formatMegabytes(1024), '< 0.1 MB');
    expect(AppCacheService.formatMegabytes(1024 * 1024 * 3 ~/ 2), '1.5 MB');
    expect(AppCacheService.formatMegabytes(1024 * 1024 * 42), '42 MB');
  });
}
