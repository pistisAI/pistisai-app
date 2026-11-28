import '../../models/conversation.dart';
import 'runtime_session_map.dart';

/// Keeps [RuntimeSessionMap] entries on the conversation they belong to, in
/// `Conversation.runtimeSessions`, so the current conversation storage saves
/// them with it (#1066, #1067). No new store is added.
///
/// The app holds one conversation today, so this store covers the
/// conversation returned by `read`. Entries for other channel ids are not
/// kept.
class ConversationRuntimeSessionStore implements RuntimeSessionMapStore {
  ConversationRuntimeSessionStore({
    required Conversation? Function() read,
    required void Function(Conversation updated) write,
  })  : _read = read,
        _write = write;

  final Conversation? Function() _read;
  final void Function(Conversation updated) _write;

  @override
  Future<Map<String, Map<String, String>>> load() async {
    final conversation = _read();
    if (conversation == null || conversation.runtimeSessions.isEmpty) {
      return {};
    }
    return {
      conversation.channelId:
          Map<String, String>.of(conversation.runtimeSessions),
    };
  }

  /// Writes the entries of the conversation's channel back onto it, in
  /// memory only. The caller saves the conversation.
  @override
  Future<void> save(Map<String, Map<String, String>> entries) async {
    final conversation = _read();
    if (conversation == null) return;
    _write(conversation.withRuntimeSessions(
      entries[conversation.channelId] ?? const {},
    ));
  }
}
