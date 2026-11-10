import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The drift scanner is a Python file shipped with the Hermes plugin. These
/// tests run it with the system Python and are skipped where there is none.
const _scanner = 'assets/pistisai/hermes/profiles/aigent-watch';

const _program = r'''
import json, sys
sys.dont_write_bytecode = True
sys.path.insert(0, sys.argv[1])
import drift_scanner
text = sys.argv[2]
print(json.dumps([c for c, _ in drift_scanner.scan_file("note.md", text)]))
''';

String? _python() {
  for (final name in ['python3', 'python']) {
    try {
      if (Process.runSync(name, ['--version']).exitCode == 0) return name;
    } on ProcessException {
      // Try the next name.
    }
  }
  return null;
}

List<String> _checks(String python, String text, {String? selfAuthored}) {
  final result = Process.runSync(
    python,
    ['-c', _program, _scanner, text],
    environment: {
      'AIGENT_WATCH_SELF_AUTHORED': selfAuthored ?? '',
      'AIGENT_DRIFT_LOG': '${Directory.systemTemp.path}/drift-test.md',
    },
  );
  expect(result.exitCode, 0, reason: '${result.stderr}');
  return (jsonDecode(result.stdout as String) as List<dynamic>).cast<String>();
}

void main() {
  final python = _python();
  final skip = python == null ? 'no Python interpreter on this machine' : null;

  test('C4 flags a cited file listed in AIGENT_WATCH_SELF_AUTHORED', () {
    final checks = _checks(
      python!,
      'This is his rule, see profile.md:8',
      selfAuthored: 'profile.md, other-notes',
    );

    expect(checks, contains('C4'));
  }, skip: skip);

  test('C4 does not flag that file when the list is empty', () {
    final checks = _checks(python!, 'This is his rule, see profile.md:8');

    expect(checks, isNot(contains('C4')));
  }, skip: skip);

  test('no generic word is built in: "dossier" with a citation is not C4',
      () {
    final checks = _checks(python!, 'See the dossier, page.md:12');

    expect(checks, isNot(contains('C4')));
  }, skip: skip);

  test('vault/Identity is always in scope', () {
    final checks = _checks(python!, 'Per vault/Identity/core.md:3');

    expect(checks, contains('C4'));
  }, skip: skip);
}
