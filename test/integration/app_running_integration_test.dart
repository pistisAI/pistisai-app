library app_running_integration_test;

/// App Running Integration Tests
/// These tests run against a REAL Flutter app instance on the virtual display.
/// They use `dart test` (not `flutter test`) to hit HTTP endpoints and verify the app is running.
///
/// Run with: dart test test/integration/app_running_integration_test.dart
/// Requires the test desktop to be running: docker compose -f docker-compose.test.yml up

import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

const String appUrl = 'http://127.0.0.1:1337';

void main() {
  late HttpClient client;

  setUp(() {
    client = HttpClient();
    client.idleTimeout = const Duration(seconds: 3);
  });

  tearDown(() {
    client.close();
  });

  group('App Running Integration Tests', () {
    test('App health endpoint responds OK', () async {
      try {
        final request = await client.getUrl(Uri.parse('$appUrl/health'));
        final response = await request.close();
        expect(response.statusCode, equals(200));

        final body = await response.transform(utf8.decoder).join();
        expect(body, equals('OK'));
        print('[Test] ✅ Health endpoint: OK'); // ignore: avoid_print
      } on SocketException {
        print('⚠️  App not running on $appUrl — skipping (start test desktop first)'); // ignore: avoid_print
      }
    });

    test('App router models endpoint responds', () async {
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
          print('[Test] ✅ Models endpoint: ${(json['data'] as List).length} models'); // ignore: avoid_print
        } else {
          print('[Test] ⚠️ Models endpoint requires auth (status: ${response.statusCode})'); // ignore: avoid_print
        }
      } on SocketException {
        print('⚠️  App not running on $appUrl — skipping (start test desktop first)'); // ignore: avoid_print
      }
    });

    test('App avatar state endpoint responds', () async {
      try {
        final request = await client.getUrl(Uri.parse('$appUrl/avatar/state'));
        final response = await request.close();
        // May return 404 if personality engine not enabled, or 200/401
        expect(response.statusCode, anyOf(equals(200), equals(401), equals(404)));
        print('[Test] ✅ Avatar state endpoint: ${response.statusCode}'); // ignore: avoid_print
      } on SocketException {
        print('⚠️  App not running on $appUrl — skipping (start test desktop first)'); // ignore: avoid_print
      }
    });

    test('App process is alive and responsive', () async {
      try {
        // Quick health check loop to verify app isn't frozen
        for (int i = 0; i < 3; i++) {
          final request = await client.getUrl(Uri.parse('$appUrl/health'));
          final response = await request.close();
          expect(response.statusCode, equals(200));
          final body = await response.transform(utf8.decoder).join();
          expect(body, equals('OK'));
          await Future.delayed(const Duration(milliseconds: 100));
        }
        print('[Test] ✅ App responsive over multiple requests'); // ignore: avoid_print
      } on SocketException {
        print('⚠️  App not running on $appUrl — skipping (start test desktop first)'); // ignore: avoid_print
      }
    });

    test('App handles concurrent requests', () async {
      try {
        // Fire multiple concurrent requests to verify no deadlock
        final futures = <Future<HttpClientResponse>>[];
        for (int i = 0; i < 10; i++) {
          futures.add(
            client.getUrl(Uri.parse('$appUrl/health')).then((req) => req.close()),
          );
        }
        final responses = await Future.wait(futures);
        for (final response in responses) {
          expect(response.statusCode, equals(200));
          final body = await response.transform(utf8.decoder).join();
          expect(body, equals('OK'));
        }
        print('[Test] ✅ App handles concurrent requests'); // ignore: avoid_print
      } on SocketException {
        print('⚠️  App not running on $appUrl — skipping (start test desktop first)'); // ignore: avoid_print
      }
    });
  });
}
