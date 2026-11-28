import 'package:flutter/foundation.dart';

import '../../models/conversation.dart';
import 'runtime_session_map.dart';

/// Keeps [RuntimeSessionMap] entries on the conversation they belong to, in
/// `Conversation.runtimeSessions`, so the current conversation storage saves
/// them with it (#1066, #1067). No new store is added.
///
/// When [readAll] is set, every channel is loaded and saved. Otherwise the
/// store covers the single conversation returned by [read].
class ConversationRuntimeSessionStore implements RuntimeSessionMapStore {
  ConversationRuntimeSessionStore({
    required Conversation? Function() read,
    required void Function(Conversation updated) write,
    List<Conversation> Function()? readAll,
    void Function(Conversation updated)? writeChannel,
  })  : _read = read,
        _write = write,
        _readAll = readAll,
        _writeChannel = writeChannel;

  final Conversation? Function() _read;
  final void Function(Conversation updated) _write;
  final List<Conversation> Function()? _readAll;
  final void Function(Conversation updated)? _writeChannel;

  @override
  Future<Map<String, Map<String, String>>> load() async {
    final all = _readAll?.call();
    if (all == null) {
      final conversation = _read();
      if (conversation == null || conversation.runtimeSessions.isEmpty) {
        return {};
      }
      return {
        conversation.channelId:
            Map<String, String>.of(conversation.runtimeSessions),
      };
    }
    final entries = <String, Map<String, String>>{};
    for (final conversation in all) {
      if (conversation.runtimeSessions.isEmpty) continue;
      entries[conversation.channelId] =
          Map<String, String>.of(conversation.runtimeSessions);
    }
    return entries;
  }

  /// Writes the entries back onto the conversations, in memory only. The
  /// caller saves them.
  @override
  Future<void> save(Map<String, Map<String, String>> entries) async {
    final all = _readAll?.call();
    final writeChannel = _writeChannel;
    if (all == null || writeChannel == null) {
      final conversation = _read();
      if (conversation == null) return;
      _write(conversation.withRuntimeSessions(
        entries[conversation.channelId] ?? const {},
      ));
      return;
    }
    for (final conversation in all) {
      final next = entries[conversation.channelId] ?? const <String, String>{};
      if (mapEquals(conversation.runtimeSessions, next)) continue;
      writeChannel(conversation.withRuntimeSessions(next));
    }
  }
}
