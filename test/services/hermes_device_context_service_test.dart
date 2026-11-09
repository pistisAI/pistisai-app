import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pistisai/services/hermes/hermes_device_context_service.dart';

void main() {
  test('reports session + device with Bearer auth', () async {
    String? capturedUrl;
    Map<String, dynamic>? capturedBody;
    String? authHeader;
    final client = MockClient((request) async {
      capturedUrl = request.url.toString();
      capturedBody = jsonDecode(request.body) as Map<String, dynamic>;
      authHeader = request.headers['Authorization'];
      return http.Response('{"context":{}}', 200);
    });

    final service = HermesDeviceContextService(
      baseUrl: 'http://127.0.0.1:8642',
      apiKey: 'sekret',
      client: client,
    );
    await service.report(location: 'Sherbrooke', connection: 'wifi');

    expect(capturedUrl, 'http://127.0.0.1:8642/api/pistisai/device-context');
    expect(authHeader, 'Bearer sekret');
    expect(capturedBody!['session'], isA<String>());
    expect(capturedBody!['device'], isA<String>());
    expect(capturedBody!['location'], 'Sherbrooke');
    expect(capturedBody!['connection'], 'wifi');
  });

  test('session id is stable within a launch', () {
    expect(HermesDeviceContextService.sessionId,
        HermesDeviceContextService.sessionId);
    expect(HermesDeviceContextService.sessionId, startsWith('sess-'));
  });

  test('omits optional fields when not provided', () async {
    Map<String, dynamic>? body;
    final client = MockClient((request) async {
      body = jsonDecode(request.body) as Map<String, dynamic>;
      return http.Response('{}', 200);
    });
    final service = HermesDeviceContextService(
      baseUrl: 'http://x:1',
      client: client,
    );
    await service.report();
    expect(body!.containsKey('location'), isFalse);
    expect(body!.containsKey('connection'), isFalse);
  });

  test('does not throw on network failure', () async {
    final client =
        MockClient((request) async => throw http.ClientException('boom'));
    final service = HermesDeviceContextService(
      baseUrl: 'http://x:1',
      client: client,
    );
    await service.report(); // must not throw
  });
}
