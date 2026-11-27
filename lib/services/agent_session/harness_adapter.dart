import 'package:flutter/foundation.dart';

import 'harness_event.dart';

/// What a harness adapter can actually do today.
///
/// Every flag defaults to `false`. An adapter sets one only when its code
/// does that work, so the UI never advertises a feature that is not there
/// (AGENTS.md, "Controls tell the truth").
@immutable
class HarnessCapabilities {
  const HarnessCapabilities({
    this.streaming = false,
    this.agentEvents = false,
    this.proactive = false,
  });

  /// [HarnessAdapter.events] carries real [HarnessDelta]s as they are
  /// written, not text reconstructed from transcript snapshots.
  final bool streaming;

  /// [HarnessAdapter.events] carries [HarnessToolStarted] and
  /// [HarnessToolFinished].
  final bool agentEvents;

  /// Messages the agent starts on its own (scheduled jobs, other devices)
  /// arrive on [HarnessAdapter.events] without a poll.
  final bool proactive;

  @override
  bool operator ==(Object other) =>
      other is HarnessCapabilities &&
      other.streaming == streaming &&
      other.agentEvents == agentEvents &&
      other.proactive == proactive;

  @override
  int get hashCode => Object.hash(streaming, agentEvents, proactive);
}

/// Contract between the hub's channel store and one agent harness
/// (Hermes first, others later) (#1066).
///
/// Every method takes the hub's channel id. Mapping it to the harness's own
/// runtime session id is the adapter's job (see `RuntimeSessionMap`), so the
/// rest of the app never sees runtime ids.
///
/// Foundation only: no adapter implements this yet and nothing in the app
/// calls it.
abstract interface class HarnessAdapter {
  /// Stable id of this harness, for example `hermes`.
  String get harnessId;

  HarnessCapabilities get capabilities;

  /// Sends one user turn to the harness. Completes once the harness has
  /// accepted it; the reply arrives on [events].
  Future<void> sendTurn(String channelId, String message);

  /// Events for [channelId]. An adapter without [HarnessCapabilities.streaming]
  /// may emit only [HarnessMessageCompleted] and [HarnessError].
  Stream<HarnessEvent> events(String channelId);

  /// History the harness holds for [channelId], oldest first; only messages
  /// after [since] when it is given. An empty list when the harness has no
  /// session for the channel yet (not an error).
  Future<List<HarnessMessage>> fetchHistory(String channelId,
      {DateTime? since});

  /// Ends the harness's runtime session for [channelId] so the next turn
  /// starts fresh. The channel and its local history are not touched.
  Future<void> resetChannel(String channelId);
}
