import '../../models/message.dart';
import '../hermes/hermes_streaming_service.dart';
import 'harness_adapter.dart';
import 'harness_event.dart';
import 'runtime_session_map.dart';

/// Harness id of Hermes in [RuntimeSessionMap] and on conversations.
const String hermesHarnessId = 'hermes';

/// [HarnessAdapter] for Hermes (#1066).
///
/// It delegates to the existing [HermesStreamingService] calls and adds no
/// new request. The Hermes session id for a channel is kept in
/// [RuntimeSessionMap]; this adapter hands it to the service before a read
/// and records what the service resolved after it.
///
/// Today's Hermes transport is polling, so every capability is false.
/// Turns are still sent with [HermesStreamingService.streamResponse] by the
/// chat service: moving the send behind [sendTurn] waits on the choice of
/// message-send endpoint (see docs/architecture/DESKTOP_SESSION_ARCHITECTURE.md).
class HermesHarnessAdapter implements HarnessAdapter {
  HermesHarnessAdapter(this.service, {required RuntimeSessionMap sessions})
      : _sessions = sessions;

  /// The streaming service this adapter delegates to.
  final HermesStreamingService service;
  final RuntimeSessionMap _sessions;

  @override
  String get harnessId => hermesHarnessId;

  @override
  HarnessCapabilities get capabilities => const HarnessCapabilities();

  /// The Hermes session id mapped to [channelId], or null before Hermes has
  /// one.
  String? runtimeSessionFor(String channelId) =>
      _sessions.runtimeSessionFor(channelId, harnessId);

  /// Not available yet: turns are sent through
  /// [HermesStreamingService.streamResponse] until the send endpoint is
  /// decided. Throws [UnsupportedError] rather than pretending to send.
  @override
  Future<void> sendTurn(String channelId, String message) {
    throw UnsupportedError(
      'Hermes turns are not sent through the harness adapter yet',
    );
  }

  /// Always empty: with no streaming, agent events or push, replies are
  /// read with [fetchHistory].
  @override
  Stream<HarnessEvent> events(String channelId) => const Stream.empty();

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

  /// Not available yet: Hermes has no call this app uses to end a session.
  /// Use [forgetRuntimeSession] to drop the local mapping only.
  @override
  Future<void> resetChannel(String channelId) {
    throw UnsupportedError(
      'Ending a Hermes session from the app is not available yet',
    );
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
