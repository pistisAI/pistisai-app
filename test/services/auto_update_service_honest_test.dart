import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('update service never fabricates download or install success', () {
    final service =
        File('lib/services/auto_update_service.dart').readAsStringSync();

    expect(service, isNot(contains('downloadUpdate')));
    expect(service, isNot(contains('installUpdate')));
    expect(service, isNot(contains('Future.delayed')));
    expect(service, contains('openReleasePage'));
  });

  test('update UI offers only an honest release-page link', () {
    final screen =
        File('lib/screens/config/config_screen.dart').readAsStringSync();

    expect(screen, isNot(contains('downloadUpdate()')));
    expect(screen, isNot(contains('installUpdate()')));
    expect(screen, isNot(contains('configUpdateReady')));
    expect(screen, contains("const Text('Open release page')"));
    expect(screen, contains('openReleasePage()'));
  });
}
