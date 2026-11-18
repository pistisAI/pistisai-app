import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:pistisai/database/drift_local_brain.dart';

/// Authorization status recorded for each agent action (#643).
abstract final class AgentAuditAuthorization {
  static const String authorized = 'authorized';
  static const String denied = 'denied';
  static const String pending = 'pending';
  static const String autoAllowed = 'auto_allowed';
  static const String unauthenticated = 'unauthenticated';
}

/// Outcome of an audited agent action.
abstract final class AgentAuditOutcome {
  static const String success = 'success';
  static const String failure = 'failure';
  static const String blocked = 'blocked';
}

/// Local-only audit journal for agent actions.
///
/// Entries never leave the device unless the client explicitly exports them.
class AgentActionAuditService {
  AgentActionAuditService({required LocalBrain database}) : _database = database;

  final LocalBrain _database;

  /// Persist one audit entry. Returns the row id.
  Future<int> record({
    required String action,
    required String dataTouched,
    required String authorizationStatus,
    required String outcome,
    String? agentId,
    String? authorizedBy,
    Map<String, dynamic>? details,
    DateTime? timestamp,
  }) {
    return _database.insertAgentActionAudit(
      AgentActionAuditEntriesCompanion.insert(
        action: action,
        dataTouched: dataTouched,
        authorizationStatus: authorizationStatus,
        outcome: outcome,
        agentId: Value(agentId),
        authorizedBy: Value(authorizedBy),
        detailsJson:
            Value(details == null ? null : jsonEncode(details)),
        timestamp: Value(timestamp ?? DateTime.now().toUtc()),
      ),
    );
  }

  /// Newest-first list of audit entries.
  Future<List<AgentActionAuditEntry>> list({int limit = 500}) =>
      _database.getAgentActionAuditEntries(limit: limit);

  /// Pretty-printed JSON array for client download/export.
  Future<String> exportJson({int limit = 10000}) async {
    final entries = await list(limit: limit);
    final payload = entries.map(_entryToMap).toList(growable: false);
    return const JsonEncoder.withIndent('  ').convert(payload);
  }

  /// CSV with a header row for spreadsheet clients.
  Future<String> exportCsv({int limit = 10000}) async {
    final entries = await list(limit: limit);
    final buffer = StringBuffer(
      'timestamp,action,dataTouched,authorizationStatus,outcome,agentId,authorizedBy\n',
    );
    for (final entry in entries) {
      buffer.writeln([
        _csv(entry.timestamp.toUtc().toIso8601String()),
        _csv(entry.action),
        _csv(entry.dataTouched),
        _csv(entry.authorizationStatus),
        _csv(entry.outcome),
        _csv(entry.agentId ?? ''),
        _csv(entry.authorizedBy ?? ''),
      ].join(','));
    }
    return buffer.toString();
  }

  /// Suggested filename for an explicit client export (local only).
  String generateExportFilename({String extension = 'json'}) {
    final stamp = DateTime.now().toUtc().toIso8601String().replaceAll(':', '-');
    return 'pistisai-agent-audit-$stamp.$extension';
  }

  Map<String, dynamic> _entryToMap(AgentActionAuditEntry entry) {
    return <String, dynamic>{
      'id': entry.id,
      'timestamp': entry.timestamp.toUtc().toIso8601String(),
      'action': entry.action,
      'dataTouched': entry.dataTouched,
      'authorizationStatus': entry.authorizationStatus,
      'outcome': entry.outcome,
      'agentId': entry.agentId,
      'authorizedBy': entry.authorizedBy,
      if (entry.detailsJson != null) 'details': _tryDecode(entry.detailsJson!),
    };
  }

  Object? _tryDecode(String raw) {
    try {
      return jsonDecode(raw);
    } catch (_) {
      return raw;
    }
  }

  String _csv(String value) {
    // Neutralise spreadsheet formula injection: cells starting with = + - @
    // (or tab / CR) are prefixed with an apostrophe so Excel/Sheets show text.
    if (value.isNotEmpty && '=+-@\t\r'.contains(value[0])) {
      value = "'$value";
    }
    if (value.contains(',') ||
        value.contains('"') ||
        value.contains('\n') ||
        value.contains('\r')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }
}
