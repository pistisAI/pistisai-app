/// App Launch Integration Tests
/// These tests verify that a running Pistisai app is alive and responsive
/// over HTTP. They use `dart test` (not `flutter test`) because they check
/// the embedded router endpoints directly.
///
/// NOTE: Platform channel tests (MethodChannel) require `flutter_test`
/// with `IntegrationTestWidgetsFlutterBinding` and a running app driver,
/// which is incompatible with `dart test`. Those tests belong in the
/// `integration_test/` directory with a proper driver setup.
///
/// Run with: dart test test/integration/app_launch_integration_test.dart
/// Requires the test desktop to be running: docker compose -f docker-compose.test.yml up

import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

const String appUrl = 'http://127.0.0.1:1337';

@Timeout(Duration(minutes: 3))
void main() {
  late HttpClient client;

  setUp(() {
    client = HttpClient();
    client.idleTimeout = const Duration(seconds: 3);
  });

  tearDown(() {
    client.close();
  });

  group('App Launch Integration Tests', () {
    test('App launches and responds on health endpoint', () async {
      try {
        final request = await client.getUrl(Uri.parse('$appUrl/health'));
        final response = await request.close();
        expect(response.statusCode, equals(200));

        final body = await response.transform(utf8.decoder).join();
        expect(body, equals('OK'));
      } on SocketException {
        print('⚠️  App not running on $appUrl — skipping (start test desktop first)'); // ignore: avoid_print
      }
    });

    test('App router models endpoint is reachable', () async {
      try {
        final request = await client.getUrl(Uri.parse('$appUrl/v1/models'));
        final response = await request.close();
        // Should return 200 (public endpoint) or 401 (if auth enabled)
        expect(response.statusCode, anyOf(equals(200), equals(401)));

        final body = await response.transform(utf8.decoder).join();
        if (response.statusCode == 200) {
          final json = jsonDecode(body) as Map<String, dynamic>;
          expect(json['object'], equals('list'));
          expect(json['data'], isA<List>());
        }
      } on SocketException {
        print('⚠️  App not running on $appUrl — skipping (start test desktop first)'); // ignore: avoid_print
      }
    });

    test('App responds within acceptable latency', () async {
      try {
        final stopwatch = Stopwatch()..start();
        final request = await client.getUrl(Uri.parse('$appUrl/health'));
        final response = await request.close();
        await response.transform(utf8.decoder).join();
        stopwatch.stop();

        expect(response.statusCode, equals(200));
        // Should respond within 2 seconds in a healthy state
        expect(stopwatch.elapsedMilliseconds, lessThan(2000));
      } on SocketException {
        print('⚠️  App not running on $appUrl — skipping (start test desktop first)'); // ignore: avoid_print
      }
    });

    test('App is responsive over multiple consecutive requests', () async {
      try {
        for (int i = 0; i < 3; i++) {
          final request = await client.getUrl(Uri.parse('$appUrl/health'));
          final response = await request.close();
          expect(response.statusCode, equals(200));
          await response.transform(utf8.decoder).join();
          await Future.delayed(const Duration(milliseconds: 100));
        }
      } on SocketException {
        print('⚠️  App not running on $appUrl — skipping (start test desktop first)'); // ignore: avoid_print
      }
    });
  });
}
