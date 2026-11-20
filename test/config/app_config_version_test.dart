import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pistisai/config/app_config.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('version is read from assets/version.json, not hard-coded', () async {
    final data = jsonDecode(File('assets/version.json').readAsStringSync())
        as Map<String, dynamic>;

    await AppConfig.loadVersionInfo();

    expect(AppConfig.appVersion, data['version']);
    expect(AppConfig.appBuildNumber, data['build_number']);
    expect(AppConfig.appVersion, isNot('1.1.100'));
  });

  test('download URLs use the asset names that actually ship', () {
    final download =
        File('lib/screens/marketing/download_screen.dart').readAsStringSync();
    final detection =
        File('lib/services/platform_detection_service.dart').readAsStringSync();

    expect(download, contains('Windows-x64-Setup.exe'));
    expect(download, contains('Windows-x64-portable.zip'));
    expect(detection, contains('Windows-x64-Setup.exe'));
    expect(detection, contains('Windows-x64-portable.zip'));
    expect(detection, isNot(contains(r'Windows-${AppConfig.appVersion}')));
    expect(download, isNot(contains('1.1.100')));
  });
}
