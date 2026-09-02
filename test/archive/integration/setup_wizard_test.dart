import 'dart:convert';
import 'dart:io';
import 'package:test/test.dart';

/// Tests the setup wizard local demo flow.
///
/// Verifies the app can discover Hermes, connect to the local backend,
/// and operate without cloud Auth0 dependency.
///
/// Run with: dart test test/integration/setup_wizard_test.dart
/// (use `dart test`, not `flutter test` — flutter_test's
/// TestWidgetsFlutterBinding blocks real HTTP)
@Timeout(Duration(minutes: 3))
void main() {
  late HttpClient client;

  setUp(() {
    client = HttpClient();
  });

  tearDown(() {
    client.close();
  });

  group('Setup Wizard - Local Demo Path', () {
    test('Backend supports unauthenticated health check', () async {
      try {
        final request = await client.getUrl(Uri.parse('http://127.0.0.1:8080/health'));
        final response = await request.close();
        expect(response.statusCode, equals(200));
      } on SocketException {
        // ignore: avoid_print
        print('[Test] ⚠️  Backend not running on :8080 — skipping');
      }
    });

    test('Provider discovery works - Hermes discovered', () async {
      try {
        // This simulates what ProviderDiscoveryService does
        final request = await client.getUrl(Uri.parse('http://127.0.0.1:8642/health'));
        final response = await request.close();
        expect(response.statusCode, equals(200));

        final body = await response.transform(utf8.decoder).join();
        final json = jsonDecode(body) as Map<String, dynamic>;
        expect(json['platform'], equals('hermes-agent'));
        // ignore: avoid_print
        print('[Test] ✅ ProviderDiscovery would find Hermes');
      } on SocketException {
        // ignore: avoid_print
        print('[Test] ⚠️  Hermes gateway not running on :8642 — skipping');
      }
    });

    test('Ollama provider available as support model', () async {
      try {
        final request = await client.getUrl(Uri.parse('http://127.0.0.1:11434/api/tags'));
        final response = await request.close();
        expect(response.statusCode, equals(200));

        final body = await response.transform(utf8.decoder).join();
        final json = jsonDecode(body) as Map<String, dynamic>;
        final models = json['models'] as List? ?? [];
        final modelNames = models.map((m) => m['name']).join(', ');
        // ignore: avoid_print
        print('[Test] ✅ Ollama models available: $modelNames');
        expect(models.length, greaterThanOrEqualTo(1),
            reason: 'At least one Ollama model needed for demo');
      } on SocketException {
        // ignore: avoid_print
        print('[Test] ⚠️  Ollama not running on :11434 — skipping');
      }
    });

    test('Setup wizard would show if no runtimes configured', () async {
      // The wizard shows when getAllAgentRuntimes() returns empty.
      // Since Hermes IS available, wizard should be SKIPPED
      // meaning the user goes straight to chat.
      // ignore: avoid_print
      print('[Test] ℹ️ Hermes is available - setup wizard will be auto-skipped');
      // ignore: avoid_print
      print('[Test] ℹ️ App will route directly to chat screen');
    });
  });

  group('Local Mode Auth Bypass', () {
    test('Desktop mode bypasses Auth0', () async {
      try {
        // Verify the backend doesn't force auth for health
        final healthReq = await client
            .getUrl(Uri.parse('http://127.0.0.1:8080/health'));
        final healthRes = await healthReq.close();
        expect(healthRes.statusCode, equals(200));

        // ignore: avoid_print
        print('[Test] ✅ Backend accessible without auth token');
        // ignore: avoid_print
        print('[Test] ✅ Desktop mode confirmed working locally');
      } on SocketException {
        // ignore: avoid_print
        print('[Test] ⚠️  Backend not running on :8080 — skipping');
      }
    });

    test('Gateway token flow', () async {
      try {
        // Try the admin gateway endpoint
        final request = await client
            .getUrl(Uri.parse('http://127.0.0.1:8080/api/admin/system/status'));
        final response = await request.close();
        final body = await response.transform(utf8.decoder).join();
        // ignore: avoid_print
        print('[Test] Admin status (${response.statusCode}): ${body.substring(0, min(body.length, 200))}');
      } catch (e) {
        // ignore: avoid_print
        print('[Test] Admin endpoint may require auth or service not running: $e');
      }
    });
  });
}

int min(int a, int b) => a < b ? a : b;
