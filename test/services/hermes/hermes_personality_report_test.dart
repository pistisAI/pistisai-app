import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pistisai/services/hermes/hermes_streaming_service.dart';

void main() {
  const traits = {
    'formality': 0.2,
    'humor': 0.8,
    'enthusiasm': 0.5,
    'empathy': 0.9,
  };

  test('posts name, traits and stage to the plugin route with the API key',
      () async {
    late http.Request seen;
    final service = HermesStreamingService(
      baseUrl: 'http://127.0.0.1:8642',
      apiKey: 'k',
      client: MockClient((request) async {
        seen = request;
        return http.Response('{"personality":{}}', 200);
      }),
    );

    final ok = await service.reportPersonality(
      agentName: 'Nova',
      traits: traits,
      evolutionStage: 'knowledge_seeker',
    );

    expect(ok, isTrue);
    expect(seen.method, 'POST');
    expect(seen.url.path, '/api/pistisai/personality');
    expect(seen.headers['Authorization'], 'Bearer k');
    final body = jsonDecode(seen.body) as Map<String, dynamic>;
    expect(body['agent_name'], 'Nova');
    expect(body['traits'], traits);
    expect(body['evolution_stage'], 'knowledge_seeker');
  });

  test('returns false and does not throw when Hermes is unreachable', () async {
    final service = HermesStreamingService(
      client: MockClient((_) async => throw http.ClientException('down')),
    );
    expect(
      await service.reportPersonality(
        agentName: 'Nova',
        traits: traits,
        evolutionStage: 'curious_explorer',
      ),
      isFalse,
    );
  });

  test('a personality that could not be sent is retried, then sent once',
      () async {
    var up = false;
    var posts = 0;
    final service = HermesStreamingService(
      client: MockClient((request) async {
        if (request.url.path != '/api/pistisai/personality') {
          return http.Response('{}', 200);
        }
        if (!up) throw http.ClientException('down');
        posts++;
        return http.Response('{"personality":{}}', 200);
      }),
    );

    await service.reportPersonality(
      agentName: 'Nova',
      traits: traits,
      evolutionStage: 'curious_explorer',
    );
    up = true;
    expect(
        await service.reportPersonality(
          agentName: 'Nova',
          traits: traits,
          evolutionStage: 'curious_explorer',
        ),
        isTrue);
    expect(posts, 1);
  });

  test('a plugin without the route (404) is not retried forever', () async {
    var posts = 0;
    final service = HermesStreamingService(
      client: MockClient((_) async {
        posts++;
        return http.Response('not found', 404);
      }),
    );
    expect(
      await service.reportPersonality(
        agentName: 'Nova',
        traits: traits,
        evolutionStage: 'curious_explorer',
      ),
      isFalse,
    );
    expect(posts, 1);
  });
}
