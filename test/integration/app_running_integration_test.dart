/// App Running Integration Tests
/// These tests run against a REAL Flutter app instance on the virtual display.
/// They use `dart test` (not `flutter test`) to hit HTTP endpoints and verify the app is running.
///
/// Run with: DISPLAY=:99 dart test test/integration/app_running_integration_test.dart
/// Or from inside test-desktop container: dart test test/integration/app_running_integration_test.dart

import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

void main() {
  late HttpClient client;

  setUp(() {
    client = HttpClient();
  });

  tearDown(() {
    client.close();
  });

  group('App Running Integration Tests', () {
    test('App health endpoint responds OK', () async {
      final request = await client.getUrl(Uri.parse('http://127.0.0.1:1337/health'));
      final response = await request.close();
      expect(response.statusCode, equals(200));

      final body = await response.transform(utf8.decoder).join();
      expect(body, equals('OK'));
      print('[Test] ✅ Health endpoint: OK');
    });

    test('App router models endpoint responds', () async {
      final request = await client.getUrl(Uri.parse('http://127.0.0.1:1337/v1/models'));
      final response = await request.close();
      // Should return 200 (public endpoint) or 401 (if auth enabled)
      expect(response.statusCode, anyOf(equals(200), equals(401)));

      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode == 200) {
        final json = jsonDecode(body) as Map<String, dynamic>;
        expect(json['object'], equals('list'));
        expect(json['data'], isA<List>());
        print('[Test] ✅ Models endpoint: ${(json['data'] as List).length} models');
      } else {
        print('[Test] ⚠️ Models endpoint requires auth (status: ${response.statusCode})');
      }
    });

    test('App avatar state endpoint responds', () async {
      final request = await client.getUrl(Uri.parse('http://127.0.0.1:1337/avatar/state'));
      final response = await request.close();
      // May return 404 if personality engine not enabled, or 200/401
      expect(response.statusCode, anyOf(equals(200), equals(401), equals(404)));
      print('[Test] ✅ Avatar state endpoint: ${response.statusCode}');
    });

    test('App process is alive and responsive', () async {
      // Quick health check loop to verify app isn't frozen
      for (int i = 0; i < 3; i++) {
        final request = await client.getUrl(Uri.parse('http://127.0.0.1:1337/health'));
        final response = await request.close();
        expect(response.statusCode, equals(200));
        final body = await response.transform(utf8.decoder).join();
        expect(body, equals('OK'));
        await Future.delayed(const Duration(milliseconds: 100));
      }
      print('[Test] ✅ App responsive over multiple requests');
    });

    test('App handles concurrent requests', () async {
      // Fire multiple concurrent requests to verify no deadlock
      final futures = <Future>[];
      for (int i = 0; i < 10; i++) {
        futures.add(client.getUrl(Uri.parse('http://127.0.0.1:1337/health')).then((req) => req.close()));
      }
      final responses = await Future.wait(futures);
      for (final response in responses) {
        expect(response.statusCode, equals(200));
        final body = await response.transform(utf8.decoder).join();
        expect(body, equals('OK'));
      }
      print('[Test] ✅ App handles concurrent requests');
    });
  });
}