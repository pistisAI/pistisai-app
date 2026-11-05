import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:pistisai/config/app_config.dart';
import 'package:pistisai/services/hermes/hermes_session_key.dart';

/// Status and body returned by the co-resident Hermes gateway.
///
/// A 404 or 409 is forwarded as-is. Callers must not treat that as an empty
/// successful sync, and this broker does not `POST /api/sessions`.
class HubForwardResult {
  final int statusCode;
  final String body;
  final String contentType;

  const HubForwardResult({
    required this.statusCode,
    required this.body,
    required this.contentType,
  });
}

/// Forwards chat send/sync from the desktop hub to local Hermes.
///
/// Non-primary clients call the hub (`:1337`). The hub dials the gateway
/// (`:8642`). The POST body is not rewritten: `conversation_id` stays the
/// platform chat id (`pistisai`), and the session key stays in the GET path.
class HermesHubBroker {
  HermesHubBroker({
    String? hermesBaseUrl,
    http.Client? client,
    this.hermesApiKey,
  })  : hermesBaseUrl =
            _stripSlash(hermesBaseUrl ?? AppConfig.defaultHermesUrl),
        _client = client ?? http.Client(),
        _ownsClient = client == null;

  final String hermesBaseUrl;
  final String? hermesApiKey;
  final http.Client _client;
  final bool _ownsClient;

  void close() {
    if (_ownsClient) _client.close();
  }

  /// `POST /api/pistisai/messages` — body forwarded unchanged.
  Future<HubForwardResult> forwardPistisaiMessage({
    required String body,
    String? authorization,
  }) async {
    final response = await _client
        .post(
          Uri.parse('$hermesBaseUrl/api/pistisai/messages'),
          headers: _headers(authorization),
          body: body,
        )
        .timeout(const Duration(seconds: 8));
    return _result(response);
  }

  /// `GET /api/sessions/{session_key}/messages`.
  ///
  /// [sessionKey] is the gateway key (`agent:main:pistisai:dm:pistisai`).
  /// It is percent-encoded as one path segment.
  Future<HubForwardResult> forwardSessionMessages({
    required String sessionKey,
    Map<String, String> queryParameters = const <String, String>{},
    String? authorization,
  }) async {
    final built = hermesSessionMessagesUri(hermesBaseUrl, sessionKey);
    final uri = queryParameters.isEmpty
        ? built
        : built.replace(queryParameters: queryParameters);
    final response = await _client
        .get(uri, headers: _headers(authorization))
        .timeout(const Duration(seconds: 8));
    return _result(response);
  }

  Map<String, String> _headers(String? authorization) {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    final key = hermesApiKey;
    if (key != null && key.isNotEmpty) {
      headers['Authorization'] = 'Bearer $key';
    } else if (authorization != null && authorization.isNotEmpty) {
      headers['Authorization'] = authorization;
    }
    return headers;
  }

  HubForwardResult _result(http.Response response) {
    final type = response.headers['content-type'];
    return HubForwardResult(
      statusCode: response.statusCode,
      body: response.body,
      contentType: (type == null || type.isEmpty) ? 'application/json' : type,
    );
  }
}

/// JSON body for a gateway the hub could not reach.
String hermesGatewayUnavailableBody() {
  return jsonEncode(<String, String>{
    'error': 'Hermes gateway unavailable',
  });
}

String _stripSlash(String url) {
  final trimmed = url.trim();
  if (trimmed.endsWith('/')) {
    return trimmed.substring(0, trimmed.length - 1);
  }
  return trimmed;
}
