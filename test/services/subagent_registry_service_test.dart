import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pistisai/services/subagent_registry_service.dart';

void main() {
  const base = 'http://api.example.com';

  test('every request carries the bearer token', () async {
    final seen = <String, String?>{};
    final client = MockClient((request) async {
      seen['${request.method} ${request.url.path}'] =
          request.headers['Authorization'];
      if (request.method == 'GET' &&
          request.url.path == '/api/admin/subagents') {
        return http.Response(
          jsonEncode({'success': true, 'subagents': <dynamic>[]}),
          200,
        );
      }
      return http.Response(jsonEncode({'success': false}), 200);
    });
    final service = SubagentRegistryService(
      apiBaseUrl: base,
      client: client,
      accessToken: () async => 'tok',
    );

    await service.listSubagents();
    await service.registerSubagent(subagentId: 'a', agentId: 'main');
    await service.getSubagent('a');
    await service.updateMetadata('a', label: 'x');
    await service.markRunning('a');
    await service.deleteSubagent('a');

    expect(seen, hasLength(greaterThanOrEqualTo(5)));
    for (final entry in seen.entries) {
      expect(entry.value, 'Bearer tok', reason: entry.key);
    }
  });

  test('sends no Authorization header when there is no token', () async {
    String? header = 'unset';
    final client = MockClient((request) async {
      header = request.headers['Authorization'];
      return http.Response(
        jsonEncode({'success': true, 'subagents': <dynamic>[]}),
        200,
      );
    });
    await SubagentRegistryService(
      apiBaseUrl: base,
      client: client,
      accessToken: () async => null,
    ).listSubagents();
    expect(header, isNull);
  });

  test('listSubagents throws with the status when the API refuses', () async {
    final service = SubagentRegistryService(
      apiBaseUrl: base,
      client: MockClient((_) async => http.Response('{}', 401)),
    );
    await expectLater(
      service.listSubagents(),
      throwsA(isA<SubagentRegistryException>()
          .having((e) => e.statusCode, 'statusCode', 401)),
    );
  });

  test('listSubagents throws when the API cannot be reached', () async {
    final service = SubagentRegistryService(
      apiBaseUrl: base,
      client: MockClient((_) async => throw http.ClientException('down')),
    );
    await expectLater(
      service.listSubagents(),
      throwsA(isA<SubagentRegistryException>()
          .having((e) => e.statusCode, 'statusCode', isNull)),
    );
  });
}
