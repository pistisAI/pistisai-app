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
  /// (`agent:main:pistisai:dm:pistisai`). Hermes stores that DM under a
  /// generated `source=pistisai` session id, which is not addressable as the
  /// gateway key, so the hub resolves that id first and falls back to
  /// [sessionKey] when the list is empty. The transcript query is fixed;
  /// caller query strings are not copied.
  Future<HubForwardResult> forwardSessionMessages({
    required String sessionKey,
  }) async {
    final resolved = await _resolvePistisaiSessionId();
    final target =
        (resolved == null || resolved.isEmpty) ? sessionKey : resolved;
    final uri = hermesSessionMessagesUri(hermesBaseUrl, target);
    final response = await _client
        .get(uri, headers: _headers())
        .timeout(hermesHubUpstreamTimeout);
    return _result(response);
  }

  /// Most recently active `source=pistisai` session, if Hermes lists one.
  Future<String?> _resolvePistisaiSessionId() async {
    try {
      final response = await _client
          .get(
            Uri.parse('$hermesBaseUrl/api/sessions?source=pistisai&limit=20'),
            headers: _headers(),
          )
          .timeout(hermesHubUpstreamTimeout);
      if (response.statusCode != 200) return null;
      final decoded = jsonDecode(response.body);
      final data = decoded is Map ? decoded['data'] : null;
      if (data is! List) return null;
      String? bestId;
      var bestActive = double.negativeInfinity;
      for (final row in data) {
        if (row is! Map) continue;
        if (row['source'] != null && row['source'] != 'pistisai') continue;
        if (row['archived'] == true || row['is_internal_child'] == true) {
          continue;
        }
        final id = row['id'];
        if (id is! String || id.isEmpty) continue;
        final active = row['last_active'] ?? row['started_at'];
        final ts =
            active is num ? active.toDouble() : double.tryParse('$active') ?? 0;
        if (ts > bestActive) {
          bestActive = ts;
          bestId = id;
        }
      }
      return bestId;
    } catch (_) {
      return null;
    }
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
