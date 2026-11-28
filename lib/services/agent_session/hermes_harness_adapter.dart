import 'dart:async';

import '../../models/message.dart';
import '../hermes/hermes_streaming_service.dart';
import 'harness_adapter.dart';
import 'harness_event.dart';
import 'runtime_session_map.dart';

/// Harness id of Hermes in [RuntimeSessionMap] and on conversations.
const String hermesHarnessId = 'hermes';

/// [HarnessAdapter] for Hermes (#1066, #1068).
///
/// Turns go to an API-server-owned Hermes session (`POST /api/sessions`,
/// then `/chat` or `/chat/stream`). The session id is a mapping in
/// [RuntimeSessionMap], never the channel's identity.
///
/// [streamTurns] is false until the live path reads `/chat/stream`. Only
/// then are [HarnessCapabilities.streaming] and [HarnessCapabilities.agentEvents]
/// true. Proactive messages are still reconciled on a timer, so
/// [HarnessCapabilities.proactive] stays false.
class HermesHarnessAdapter implements HarnessAdapter {
  HermesHarnessAdapter(
    this.service, {
    required RuntimeSessionMap sessions,
    this.streamTurns = false,
  }) : _sessions = sessions;

  /// The streaming service this adapter delegates to.
  final HermesStreamingService service;
  final RuntimeSessionMap _sessions;

  /// When true, [sendTurn] reads `/api/sessions/{id}/chat/stream`.
  final bool streamTurns;

  final StreamController<HarnessEvent> _events =
      StreamController<HarnessEvent>.broadcast();

  @override
  String get harnessId => hermesHarnessId;

  @override
  HarnessCapabilities get capabilities => HarnessCapabilities(
        streaming: streamTurns,
        agentEvents: streamTurns,
      );

  /// The Hermes session id mapped to [channelId], or null before Hermes has
  /// one.
  String? runtimeSessionFor(String channelId) =>
      _sessions.runtimeSessionFor(channelId, harnessId);

  /// Sends [message] on the channel's API-server session. The reply is
  /// emitted on [events] as [HarnessMessageCompleted], or as deltas when
  /// [streamTurns] is set.
  @override
  Future<void> sendTurn(String channelId, String message) async {
    service.restoreRuntimeSession(channelId, runtimeSessionFor(channelId));
    final sessionId = await service.ensureOwnedSession(channelId);
    await _recordRuntimeSession(channelId);
    if (sessionId == null) {
      _emit(HarnessError(
        channelId: channelId,
        message: 'Could not open a Hermes session for this chat.',
        retryable: true,
      ));
      return;
    }
    if (!streamTurns) {
      final text = await service.postOwnedSessionChat(
        sessionId: sessionId,
        message: message,
      );
      if (text == null) {
        _emit(HarnessError(
          channelId: channelId,
          message: 'Hermes did not accept that turn.',
          retryable: true,
        ));
        return;
      }
      _emit(HarnessMessageCompleted(
        channelId: channelId,
        message: HarnessMessage(
          id: 'hermes-$sessionId-${DateTime.now().microsecondsSinceEpoch}',
          role: HarnessRole.assistant,
          content: text,
          createdAt: DateTime.now().toUtc(),
        ),
      ));
      return;
    }
    await for (final event in service.streamOwnedSessionChat(
      channelId: channelId,
      sessionId: sessionId,
      message: message,
    )) {
      _emit(event);
    }
  }

  /// Events for [channelId].
  @override
  Stream<HarnessEvent> events(String channelId) {
    return _events.stream.where((event) => event.channelId == channelId);
  }

  void _emit(HarnessEvent event) {
    if (!_events.isClosed) _events.add(event);
  }

  /// Reads the Hermes transcript of [channelId] with
  /// [HermesStreamingService.fetchSessionMessages]. Empty when Hermes has no
  /// session for the channel yet. Throws [HarnessUnavailableException] when
  /// the transcript could not be read.
  @override
  Future<List<HarnessMessage>> fetchHistory(
    String channelId, {
    DateTime? since,
  }) async {
    service.restoreRuntimeSession(channelId, runtimeSessionFor(channelId));
    final fetched = await service.fetchSessionMessages(channelId);
    await _recordRuntimeSession(channelId);
    if (fetched == null) {
      throw HarnessUnavailableException(
        harnessId,
        'could not read the Hermes transcript',
      );
    }
    return [
      for (final message in fetched)
        if (since == null || message.timestamp.isAfter(since))
          HarnessMessage(
            id: message.id,
            role: _role(message.role),
            content: message.content,
            createdAt: message.timestamp,
          ),
    ];
  }

  /// Deletes the API-server session for [channelId] and forgets the mapping.
  /// The channel and its local history are not touched.
  @override
  Future<void> resetChannel(String channelId) async {
    final sessionId = runtimeSessionFor(channelId);
    service.restoreRuntimeSession(channelId, sessionId);
    final resolved = sessionId ?? service.runtimeSessionIdFor(channelId);
    if (resolved != null) {
      final deleted = await service.deleteOwnedSession(resolved);
      if (!deleted) {
        throw HarnessUnavailableException(
          harnessId,
          'could not end the Hermes session',
        );
      }
    }
    await forgetRuntimeSession(channelId);
  }

  /// Forgets the Hermes session mapped to [channelId], here and in the
  /// service (for example after a local data wipe). The Hermes session
  /// itself is not touched; the next read resolves it again.
  Future<void> forgetRuntimeSession(String channelId) async {
    service.clearRuntimeSession(channelId);
    await _sessions.clear(channelId, harnessId: harnessId);
  }

  Future<void> _recordRuntimeSession(String channelId) async {
    final resolved = service.runtimeSessionIdFor(channelId);
    if (resolved == null) {
      await _sessions.clear(channelId, harnessId: harnessId);
    } else {
      await _sessions.bind(channelId, harnessId, resolved);
    }
  }

  static HarnessRole _role(MessageRole role) => switch (role) {
        MessageRole.user => HarnessRole.user,
        MessageRole.assistant => HarnessRole.assistant,
        MessageRole.system => HarnessRole.system,
      };
}
