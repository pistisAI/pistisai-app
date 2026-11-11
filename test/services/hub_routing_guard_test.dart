import 'package:flutter_test/flutter_test.dart';
import 'package:pistisai/config/app_config.dart';
import 'package:pistisai/services/connection_manager_service.dart';

void main() {
  test('isDirectHermesUrl detects the co-resident Hermes port', () {
    expect(
      ConnectionManagerService.isDirectHermesUrl(
        'http://127.0.0.1:' + AppConfig.defaultHermesPort.toString(),
      ),
      isTrue,
    );
    expect(
      ConnectionManagerService.isDirectHermesUrl(
        'http://pc.ts.net:' + AppConfig.defaultRouterPort.toString(),
      ),
      isFalse,
    );
  });
}
