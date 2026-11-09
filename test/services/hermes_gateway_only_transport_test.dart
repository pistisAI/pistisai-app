import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Hermes chat transport is gateway-only', () {
    final forbidden = <String>[
      'HermesProcessClient',
      'HermesProcessBackedRuntimeClient',
      'hermes_process_client.dart',
      'hermes_process_backed_runtime_client.dart',
    ];

    final violations = <String>[];
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;

      final source = entity.readAsStringSync();
      for (final token in forbidden) {
        if (source.contains(token)) {
          violations.add('${entity.path}: $token');
        }
      }
    }

    expect(
      violations,
      isEmpty,
      reason: 'PistisAI must route Hermes chat through the authenticated '
          'gateway/API server rather than spawning Hermes child processes.',
    );
  });
}
