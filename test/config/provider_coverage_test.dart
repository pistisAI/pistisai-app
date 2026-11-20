import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Every type a widget reads from Provider must be provided somewhere:
/// by the app-level list in lib/main.dart, or by a local provider in the
/// same file. Otherwise the screen throws ProviderNotFoundException when it
/// opens (issue #853).
void main() {
  test('every type read from Provider is provided', () {
    final readPattern = RegExp(
      r'(?:context\.(?:watch|read|select)<|Provider\.of<|Consumer2?<)'
      r'([A-Z][A-Za-z0-9_]*)',
    );
    // Read inside a try/catch with a service-locator fallback.
    const withFallback = {'RateLimitManager'};

    final mainSource = File('lib/main.dart').readAsStringSync();
    final missing = <String>[];

    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      if (entity.path.endsWith('.g.dart')) continue;
      final source = entity.readAsStringSync();
      for (final match in readPattern.allMatches(source)) {
        final type = match.group(1)!;
        if (withFallback.contains(type)) continue;
        final inMain = mainSource.contains('<$type>(') ||
            mainSource.contains('Provider<$type>');
        final local = source.contains('Provider<$type>');
        if (!inMain && !local) missing.add('$type in ${entity.path}');
      }
    }

    expect(missing.toSet().toList()..sort(), isEmpty);
  });
}
