import '../../models/message.dart';

/// Platform chat id and Hermes gateway session key for the shared desktop DM.
///
/// The UI / platform chat id (`pistisai`) is what `POST /api/pistisai/messages`
/// sends as `conversation_id`. The transcript lives on the gateway session
/// key `agent:main:pistisai:dm:<chat_id>`, which is what
/// `GET /api/sessions/{session_key}/messages` must use. Those two strings are
/// never interchangeable: posting or polling the short id 404s, and creating
/// that short id returns 409 once Hermes already owns the real session.

/// Platform name inside the Hermes session key.
const hermesPistisaiPlatform = 'pistisai';

/// Chat id of the one shared desktop DM.
const pistisaiPlatformChatId = 'pistisai';

/// Local conversation shell ids that still mean the shared desktop DM.
///
/// `main-channel` is the on-disk conversation id. It is not a Hermes session.
const hermesSharedUiIds = <String>{
  pistisaiPlatformChatId,
  'main-channel',
  'pistisai-chat',
};

/// Shown when a transcript poll fails. Not an empty successful sync.
const sharedChannelSyncError =
    'The shared conversation could not be read from Hermes. Retrying shortly.';

/// True when [value] is a gateway DM session key, not a short chat id.
bool isHermesGatewaySessionKey(String value) {
  return value.startsWith('agent:') && value.contains(':dm:');
}

/// Platform chat id for [uiId]. Never returns a session key.
String platformChatIdForUiId(String uiId) {
  final trimmed = uiId.trim();
  if (trimmed.isEmpty || hermesSharedUiIds.contains(trimmed)) {
    return pistisaiPlatformChatId;
  }
  if (isHermesGatewaySessionKey(trimmed)) {
    final marker = ':dm:';
    final index = trimmed.lastIndexOf(marker);
    final chatId = trimmed.substring(index + marker.length);
    if (chatId.isEmpty) return pistisaiPlatformChatId;
    return chatId;
  }
  return trimmed;
}

/// Gateway session key for a Pistisai DM.
///
/// Default UI id `pistisai` (and the local `main-channel` shell) map to
/// `agent:main:pistisai:dm:pistisai`.
String hermesSessionKeyForUiId(
  String uiId, {
  String agent = 'main',
  String platform = hermesPistisaiPlatform,
}) {
  final trimmed = uiId.trim();
  if (isHermesGatewaySessionKey(trimmed)) return trimmed;
  final chatId = platformChatIdForUiId(trimmed);
  return 'agent:$agent:$platform:dm:$chatId';
}

/// Transcript URL. The session key is one path segment, so `:` is `%3A`.
///
/// Built from an already-encoded path. [Uri.pathSegments] leaves `:` raw.
Uri hermesSessionMessagesUri(String baseUrl, String sessionKey) {
  final base = baseUrl.endsWith('/')
      ? baseUrl.substring(0, baseUrl.length - 1)
      : baseUrl;
  return Uri.parse(
    '$base/api/sessions/${Uri.encodeComponent(sessionKey)}/messages'
    '?order=oldest&limit=500',
  );
}

/// How long to wait before the next poll after a failed read.
///
/// 2s, 4s, 8s, 16s, then 32s. A failed read must not spin.
Duration sharedChannelFailureBackoff(int consecutiveFailures) {
  var step = consecutiveFailures;
  if (step < 1) step = 1;
  if (step > 5) step = 5;
  return Duration(seconds: 1 << step);
}

/// Whether a transcript poll may replace the on-screen thread.
class SharedChannelSyncPlan {
  final bool applyTranscript;
  final Duration retryAfter;
  final String? error;

  const SharedChannelSyncPlan({
    required this.applyTranscript,
    required this.retryAfter,
    required this.error,
  });

  factory SharedChannelSyncPlan.fromPoll({
    required bool healthy,
    required int consecutiveFailures,
  }) {
    if (healthy) {
      return const SharedChannelSyncPlan(
        applyTranscript: true,
        retryAfter: Duration.zero,
        error: null,
      );
    }
    return SharedChannelSyncPlan(
      applyTranscript: false,
      retryAfter: sharedChannelFailureBackoff(consecutiveFailures),
      error: sharedChannelSyncError,
    );
  }
}

/// Blocks another poll until [retryAfter] from the last failure has elapsed.
class SharedChannelSyncGate {
  SharedChannelSyncGate({DateTime Function()? clock})
      : _clock = clock ?? DateTime.now;

  final DateTime Function() _clock;
  DateTime _notBefore = DateTime.fromMillisecondsSinceEpoch(0);
  int _failures = 0;

  int get failures => _failures;

  bool get shouldPoll => !_clock().isBefore(_notBefore);

  void reset() {
    _failures = 0;
    _notBefore = DateTime.fromMillisecondsSinceEpoch(0);
  }

  void record({required bool healthy, required Duration retryAfter}) {
    if (healthy) {
      _failures = 0;
      _notBefore = _clock();
      return;
    }
    _failures += 1;
    _notBefore = _clock().add(retryAfter);
  }
}

/// Session key returned by a gateway response, or null when it is not one.
///
/// `id: pistisai` and any 4xx body are ignored so a 409 cannot lock the
/// short chat id as the runtime session.
String? adoptGatewaySessionKey({
  required int? statusCode,
  required Object? body,
}) {
  if (statusCode == null || statusCode < 200 || statusCode >= 300) {
    return null;
  }
  return _gatewayKeyIn(body);
}

String? _gatewayKeyIn(Object? body) {
  if (body is! Map) return null;
  final map = Map<Object?, Object?>.from(body);
  for (final field in const <String>[
    'session_key',
    'sessionKey',
    'session_id',
  ]) {
    final value = map[field];
    if (value is String && isHermesGatewaySessionKey(value)) return value;
  }
  final nested = map['session'];
  if (nested is Map) return _gatewayKeyIn(nested);
  return null;
}

/// One `POST /api/pistisai/messages` attempt.
///
/// [conversationId] is the platform chat id. [sessionKey] is the transcript
/// key and is never written into that POST body.
class HermesChannelDelivery {
  final String conversationId;
  final String sessionKey;
  final int? statusCode;
  final String? adoptedSessionKey;

  /// A 409 must not lock the short chat id. This stays false.
  bool get boundShortId => false;

  const HermesChannelDelivery({
    required this.conversationId,
    required this.sessionKey,
    required this.statusCode,
    required this.adoptedSessionKey,
  });
}

/// One transcript GET.
///
/// [isHealthy] is true only for HTTP 200. A 404 or 409 leaves [messages]
/// null so an empty list cannot be mistaken for a successful sync.
class HermesTranscriptPoll {
  final String sessionKey;
  final Uri pollUri;
  final int? statusCode;
  final List<Message>? messages;

  /// A failed read must not lock the short chat id. This stays false.
  bool get boundShortId => false;

  bool get isHealthy => statusCode == 200 && messages != null;

  const HermesTranscriptPoll({
    required this.sessionKey,
    required this.pollUri,
    required this.statusCode,
    required this.messages,
  });
}
