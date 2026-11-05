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

/// How long the hub waits for the co-resident gateway.
///
/// Clients that send through the hub wait longer than this so they observe
/// the proxy status instead of timing out while the hop is still in flight.
const Duration hermesHubUpstreamTimeout = Duration(seconds: 8);

/// Forwards chat send/sync from the desktop hub to local Hermes.
///
/// Non-primary clients call the hub (`:1337`). The hub dials the gateway
/// (`:8642`) with its own discovered API key. Caller Authorization headers
/// are not forwarded. The POST body is not rewritten: `conversation_id`
/// stays the platform chat id (`pistisai`).
class HermesHubBroker {
  HermesHubBroker({
    String? hermesBaseUrl,
    http.Client? client,
    this.hermesApiKey,
  })  : hermesBaseUrl = _stripSlash(
          (hermesBaseUrl == null || hermesBaseUrl.trim().isEmpty)
              ? AppConfig.defaultHermesUrl
              : hermesBaseUrl,
        ),
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
  }) async {
    final response = await _client
        .post(
          Uri.parse('$hermesBaseUrl/api/pistisai/messages'),
          headers: _headers(),
          body: body,
        )
        .timeout(hermesHubUpstreamTimeout);
    return _result(response);
  }

  /// `GET /api/sessions/{session_key}/messages`.
  ///
  /// [sessionKey] must already be the allowlisted Pistisai DM key
  /// (`agent:main:pistisai:dm:pistisai`). It is percent-encoded as one path
  /// segment. The transcript query is fixed; caller query strings are not
  /// copied.
  Future<HubForwardResult> forwardSessionMessages({
    required String sessionKey,
  }) async {
    final uri = hermesSessionMessagesUri(hermesBaseUrl, sessionKey);
    final response = await _client
        .get(uri, headers: _headers())
        .timeout(hermesHubUpstreamTimeout);
    return _result(response);
  }

  /// Upstream identity is the hub's discovered Hermes key only.
  Map<String, String> _headers() {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    final key = hermesApiKey;
    if (key != null && key.isNotEmpty) {
      headers['Authorization'] = 'Bearer $key';
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
