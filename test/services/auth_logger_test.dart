import 'package:flutter_test/flutter_test.dart';
import 'package:pistisai/services/auth_logger.dart';

void main() {
  group('AuthLogger', () {
    setUp(AuthLogger.clearLogs);

    test('includes message text in log entries', () {
      AuthLogger.info('user signed in', {'userId': 'abc'});
      AuthLogger.error('token validation failed');

      final logs = AuthLogger.getLogs();
      expect(logs.length, 2);
      expect(logs.first, contains('[INFO]'));
      expect(logs.first, contains('user signed in'));
      expect(logs.last, contains('[ERROR]'));
      expect(logs.last, contains('token validation failed'));
    });

    test('downloadLogs is a no-op when there are no logs', () {
      expect(() => AuthLogger.downloadLogs(), returnsNormally);
    });
  });
}
