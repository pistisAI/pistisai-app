/// Tables for hub-owned conversation channels (#1065, #1067).
///
/// These live in the Drift/SQLite database (`local_brain.sqlite`), which is
/// the canonical conversation store. They are created with SQL rather than
/// Drift table classes so the existing generated database code stays
/// untouched. [LocalBrain.ensureHubChannelTables] runs the statements.
const List<String> hubChannelSchemaStatements = <String>[
  '''
  CREATE TABLE IF NOT EXISTS hub_channels (
    id TEXT NOT NULL PRIMARY KEY,
    kind TEXT NOT NULL,
    title TEXT NOT NULL,
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL,
    model TEXT,
    metadata_json TEXT NOT NULL DEFAULT '{}',
    runtime_sessions_json TEXT NOT NULL DEFAULT '{}',
    hermes_history_imported INTEGER NOT NULL DEFAULT 0
  )
  ''',
  '''
  CREATE TABLE IF NOT EXISTS hub_channel_messages (
    channel_id TEXT NOT NULL,
    position INTEGER NOT NULL,
    message_id TEXT NOT NULL,
    payload_json TEXT NOT NULL,
    PRIMARY KEY (channel_id, position)
  )
  ''',
  '''
  CREATE TABLE IF NOT EXISTS hub_store_flags (
    flag_key TEXT NOT NULL PRIMARY KEY,
    flag_value TEXT NOT NULL
  )
  ''',
];

/// Flag set after `conversations.json.enc` has been imported once.
const String hubJsonImportedFlag = 'conversations_json_imported';
