import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Reports this desktop/mobile session's device context to Hermes.
///
/// The pistisai plugin's awareness hook (`pre_llm_call`) reads the same
/// `device-context.json` on the Hermes host and injects it into every turn,
/// so the agent knows which PC and which session the user is on. The Hermes
/// host also adds its own hostname, so the PC name needs no client help.
class HermesDeviceContextService {
  HermesDeviceContextService({
    required this.baseUrl,
    this.apiKey,
    http.Client? client,
  }) : _client = client ?? http.Client();

  final String baseUrl;
  final String? apiKey;
  final http.Client _client;

  /// One id per app launch — a "desktop session". Regenerated on restart.
  static String? _sessionId;
  static String get sessionId => _sessionId ??= _newSessionId();

  /// Stable device id for this install/launch. Used as the per-source key so
  /// multiple desktops on one Hermes host don't stomp each other's context.
  static String? _deviceId;
  static String get deviceId => _deviceId ??= _newDeviceId();

  static String _newDeviceId() {
    final rnd = Random.secure();
    final suffix =
        List<int>.generate(8, (_) => rnd.nextInt(16)).map((n) => n.toRadixString(16)).join();
    return 'dev-${DateTime.now().millisecondsSinceEpoch}-$suffix';
  }

  static String _newSessionId() {
    final rnd = Random.secure();
    final suffix =
        List<int>.generate(8, (_) => rnd.nextInt(16)).map((n) => n.toRadixString(16)).join();
    return 'sess-${DateTime.now().millisecondsSinceEpoch}-$suffix';
  }

  /// Coarse device kind for the awareness block.
  static String get deviceKind {
    if (kIsWeb) return 'web';
    if (Platform.isAndroid || Platform.isIOS) return 'phone';
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      return 'desktop';
    }
    return 'device';
  }

  Uri get _uri => Uri.parse('$baseUrl/api/pistisai/device-context');

  /// POST this session's context to Hermes. Best-effort: never throws.
  Future<void> report({String? location, String? connection}) async {
    try {
      final body = jsonEncode(<String, dynamic>{
        'source': 'api_server:$deviceId',
        'session': sessionId,
        'device': deviceKind,
        if (location != null && location.isNotEmpty) 'location': location,
        if (connection != null && connection.isNotEmpty) 'connection': connection,
      });
      final headers = <String, String>{
        'Content-Type': 'application/json',
        'X-Device-Id': deviceId,
      };
      final key = apiKey;
      if (key != null && key.isNotEmpty) {
        headers['Authorization'] = 'Bearer $key';
      }
      final res = await _client
          .post(_uri, headers: headers, body: body)
          .timeout(const Duration(seconds: 5));
      debugPrint('[HermesDeviceContext] report -> ${res.statusCode}');
    } catch (e) {
      debugPrint('[HermesDeviceContext] report failed: $e');
    }
  }
}
