/// Persistence for [RuntimeSessionMap]. Injected so the map stays free of
/// I/O and can be tested without a database.
abstract interface class RuntimeSessionMapStore {
  /// channelId -> harnessId -> runtime session id.
  Future<Map<String, Map<String, String>>> load();

  Future<void> save(Map<String, Map<String, String>> entries);
}

/// Keeps entries in memory only. For tests, and for callers that do not
/// need the mapping to survive a restart.
class InMemoryRuntimeSessionMapStore implements RuntimeSessionMapStore {
  Map<String, Map<String, String>> _entries = {};

  @override
  Future<Map<String, Map<String, String>>> load() async => _copy(_entries);

  @override
  Future<void> save(Map<String, Map<String, String>> entries) async {
    _entries = _copy(entries);
  }
}

Map<String, Map<String, String>> _copy(Map<String, Map<String, String>> m) => {
      for (final e in m.entries) e.key: Map<String, String>.of(e.value),
    };

/// Maps a hub channel id to the runtime session id each harness uses for it
/// (#1065, #1067).
///
/// A runtime session id is an adapter detail: it can change when the harness
/// rotates its session (for example on `/new`) and it is never the identity
/// of the conversation. Clearing a mapping does not touch the channel or its
/// history.
///
/// Foundation only: nothing in the app uses this yet.
class RuntimeSessionMap {
  RuntimeSessionMap._(this._store, this._entries);

  /// Loads the current mappings from [store].
  static Future<RuntimeSessionMap> load(RuntimeSessionMapStore store) async {
    return RuntimeSessionMap._(store, _copy(await store.load()));
  }

  final RuntimeSessionMapStore _store;
  final Map<String, Map<String, String>> _entries;

  /// Runtime session id of [harnessId] for [channelId], or null when that
  /// harness has no session for the channel yet.
  String? runtimeSessionFor(String channelId, String harnessId) =>
      _entries[channelId]?[harnessId];

  /// All harness mappings of [channelId] (harnessId -> runtime session id).
  Map<String, String> sessionsFor(String channelId) =>
      Map.unmodifiable(_entries[channelId] ?? const <String, String>{});

  /// Records that [harnessId] uses [runtimeSessionId] for [channelId],
  /// replacing any earlier id for that harness.
  Future<void> bind(
    String channelId,
    String harnessId,
    String runtimeSessionId,
  ) async {
    _requireId(channelId, 'channelId');
    _requireId(harnessId, 'harnessId');
    _requireId(runtimeSessionId, 'runtimeSessionId');
    if (_entries[channelId]?[harnessId] == runtimeSessionId) return;
    (_entries[channelId] ??= {})[harnessId] = runtimeSessionId;
    await _store.save(_entries);
  }

  /// Forgets the mapping of [harnessId] for [channelId], or every harness's
  /// mapping for the channel when [harnessId] is null.
  Future<void> clear(String channelId, {String? harnessId}) async {
    final sessions = _entries[channelId];
    if (sessions == null) return;
    if (harnessId == null) {
      _entries.remove(channelId);
    } else {
      if (sessions.remove(harnessId) == null) return;
      if (sessions.isEmpty) _entries.remove(channelId);
    }
    await _store.save(_entries);
  }

  static void _requireId(String value, String name) {
    if (value.trim().isEmpty) {
      throw ArgumentError.value(value, name, 'must not be empty');
    }
  }
}
