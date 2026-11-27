/// Client-facing export and permanent deletion for local agent data.
library;

import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:pistisai/brand/brand.dart';
import 'package:pistisai/database/drift_local_brain.dart';
import 'package:pistisai/services/agent_action_audit_service.dart';

/// Result of a one-shot local agent data deletion.
class LocalAgentDataDeletionResult {
  const LocalAgentDataDeletionResult({
    required this.deletedAt,
    required this.deletedRowCounts,
    required this.duration,
    required this.verifiedEmpty,
    required this.conversationsCleared,
    required this.verification,
  });

  final DateTime deletedAt;
  final Map<String, int> deletedRowCounts;
  final Duration duration;
  final bool verifiedEmpty;
  final bool conversationsCleared;
  final LocalAgentDataVerification verification;

  Map<String, dynamic> toJson() => {
        'deletedAt': deletedAt.toIso8601String(),
        'deletedRowCounts': deletedRowCounts,
        'durationMs': duration.inMilliseconds,
        'verifiedEmpty': verifiedEmpty,
        'conversationsCleared': conversationsCleared,
        'verification': verification.toJson(),
      };
}

/// Post-deletion verification snapshot.
class LocalAgentDataVerification {
  const LocalAgentDataVerification({
    required this.checkedAt,
    required this.remainingUserContentCounts,
    required this.allTableCounts,
    required this.isEmpty,
    this.remainingConversationFiles = const <String>[],
    this.remainingPlainFiles = const <String>[],
  });

  final DateTime checkedAt;
  final Map<String, int> remainingUserContentCounts;
  final Map<String, int> allTableCounts;
  final bool isEmpty;
  final List<String> remainingConversationFiles;

  /// Plain files the app wrote outside the encrypted stores (avatar Markdown
  /// in the agent skill folder, temp captures) that still exist.
  final List<String> remainingPlainFiles;

  Map<String, dynamic> toJson() => {
        'checkedAt': checkedAt.toIso8601String(),
        'remainingUserContentCounts': remainingUserContentCounts,
        'allTableCounts': allTableCounts,
        'remainingConversationFiles': remainingConversationFiles,
        'remainingPlainFiles': remainingPlainFiles,
        'isEmpty': isEmpty,
      };
}

/// Export and permanently delete all local agent data stored by Pistisai.
///
/// Scope is the on-device [LocalBrain] SQLite database, optionally the
/// encrypted conversation file store, and optionally the plain files the app
/// writes outside those stores (avatar Markdown, temp captures). Cloud account
/// deletion and the agent runtime's own transcript are separate.
class LocalAgentDataPortabilityService {
  LocalAgentDataPortabilityService({
    required LocalBrain brain,
    Future<Map<String, dynamic>> Function()? exportConversations,
    Future<void> Function()? clearConversations,
    Future<List<String>> Function()? listRemainingConversationFiles,
    Future<void> Function()? resetChatState,
    List<Future<void> Function()> clearPlainFiles = const [],
    List<Future<List<String>> Function()> listRemainingPlainFiles = const [],
    AgentActionAuditService? audit,
  })  : _brain = brain,
        _exportConversations = exportConversations,
        _clearConversations = clearConversations,
        _listRemainingConversationFiles = listRemainingConversationFiles,
        _resetChatState = resetChatState,
        _clearPlainFiles = clearPlainFiles,
        _listRemainingPlainFiles = listRemainingPlainFiles,
        _audit = audit;

  static const String exportVersion = '1.0';
  static const String exportFormat = 'pistisai-local-agent-data';
  static const String fileExtension = '.json';

  /// Audit action written after a verified wipe (not treated as leftover content).
  static const String wipeAuditAction = 'local_data_wipe';

  /// Placeholder reported when a plain-file location could not be checked.
  static const String unverifiedPlainFileLocation = '(location not checked)';

  static String get filePrefix =>
      '${Brand.current.artifactPrefix}-local-agent-data';

  final LocalBrain _brain;
  final Future<Map<String, dynamic>> Function()? _exportConversations;
  final Future<void> Function()? _clearConversations;
  final Future<List<String>> Function()? _listRemainingConversationFiles;
  final Future<void> Function()? _resetChatState;
  final List<Future<void> Function()> _clearPlainFiles;
  final List<Future<List<String>> Function()> _listRemainingPlainFiles;
  final AgentActionAuditService? _audit;

  /// Export all local agent data as indented JSON.
  Future<String> exportAllToJson() async {
    final tables = await _brain.exportAllTablesAsMaps();
    final rowCounts = <String, int>{
      for (final entry in tables.entries) entry.key: entry.value.length,
    };

    Map<String, dynamic>? conversations;
    if (_exportConversations != null) {
      conversations = await _exportConversations();
    }

    final payload = <String, dynamic>{
      'version': exportVersion,
      'format': exportFormat,
      'exportedAt': DateTime.now().toIso8601String(),
      'tables': tables,
      'rowCounts': rowCounts,
      if (conversations != null) 'conversationsFile': conversations,
    };

    return const JsonEncoder.withIndent('  ').convert(payload);
  }

  /// Suggested download filename for an export.
  String generateExportFilename() {
    final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
    return '$filePrefix-$timestamp$fileExtension';
  }

  /// Permanently delete all local agent data in one action, then verify.
  Future<LocalAgentDataDeletionResult> deleteAllLocalAgentData({
    bool reseedDefaults = true,
  }) async {
    final started = DateTime.now();
    final deletedRowCounts = await _brain.deleteAllAgentData(
      reseedDefaults: reseedDefaults,
    );

    var conversationsCleared = false;
    if (_clearConversations != null) {
      await _clearConversations();
      conversationsCleared = true;
    }

    for (final clear in _clearPlainFiles) {
      try {
        await clear();
      } catch (_) {
        // A file that could not be removed is reported by verification.
      }
    }

    final verification = await verifyDeletion();

    if (verification.isEmpty && _audit != null) {
      await _audit.record(
        action: wipeAuditAction,
        dataTouched: 'local_brain+conversation_files+plain_files',
        authorizationStatus: AgentAuditAuthorization.authorized,
        outcome: AgentAuditOutcome.success,
        authorizedBy: 'user',
        details: {
          'deletedRowCounts': deletedRowCounts,
          'conversationsCleared': conversationsCleared,
          'durationMs': DateTime.now().difference(started).inMilliseconds,
        },
      );
    }

    if (_resetChatState != null) {
      await _resetChatState();
    }

    final finished = DateTime.now();

    return LocalAgentDataDeletionResult(
      deletedAt: finished,
      deletedRowCounts: deletedRowCounts,
      duration: finished.difference(started),
      verifiedEmpty: verification.isEmpty,
      conversationsCleared: conversationsCleared,
      verification: verification,
    );
  }

  /// Count remaining user-content rows and conversation files.
  ///
  /// [isEmpty] is true when every user-content table has zero rows (aside from
  /// the post-wipe [wipeAuditAction] journal entry) and no conversation data
  /// files or plain app files remain.
  Future<LocalAgentDataVerification> verifyDeletion() async {
    final allCounts = await _brain.countAllTableRows();
    final userCounts = <String, int>{
      for (final name in LocalBrain.userContentTableNames)
        name: allCounts[name] ?? 0,
    };

    if (userCounts.containsKey('agent_action_audit_entries')) {
      userCounts['agent_action_audit_entries'] =
          await _countNonWipeAuditEntries();
    }

    final remainingFiles = _listRemainingConversationFiles != null
        ? await _listRemainingConversationFiles()
        : const <String>[];

    final remainingPlain = <String>[];
    for (final list in _listRemainingPlainFiles) {
      try {
        remainingPlain.addAll(await list());
      } catch (_) {
        // A location that cannot be checked is not reported as empty.
        remainingPlain.add(unverifiedPlainFileLocation);
      }
    }

    final empty = userCounts.values.every((count) => count == 0) &&
        remainingFiles.isEmpty &&
        remainingPlain.isEmpty;

    return LocalAgentDataVerification(
      checkedAt: DateTime.now(),
      remainingUserContentCounts: userCounts,
      allTableCounts: allCounts,
      remainingConversationFiles: remainingFiles,
      remainingPlainFiles: remainingPlain,
      isEmpty: empty,
    );
  }

  Future<int> _countNonWipeAuditEntries() async {
    final row = await _brain.customSelect(
      'SELECT COUNT(*) AS c FROM agent_action_audit_entries WHERE action != ?',
      variables: [Variable.withString(wipeAuditAction)],
      readsFrom: {_brain.agentActionAuditEntries},
    ).getSingle();
    return row.read<int>('c');
  }
}
