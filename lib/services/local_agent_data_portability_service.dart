/// Client-facing export and permanent deletion for local agent data.
library;

import 'dart:convert';

import 'package:pistisai/brand/brand.dart';
import 'package:pistisai/database/drift_local_brain.dart';

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
  });

  final DateTime checkedAt;
  final Map<String, int> remainingUserContentCounts;
  final Map<String, int> allTableCounts;
  final bool isEmpty;

  Map<String, dynamic> toJson() => {
        'checkedAt': checkedAt.toIso8601String(),
        'remainingUserContentCounts': remainingUserContentCounts,
        'allTableCounts': allTableCounts,
        'isEmpty': isEmpty,
      };
}

/// Export and permanently delete all local agent data stored by Pistisai.
///
/// Scope is the on-device [LocalBrain] SQLite database (and optionally the
/// encrypted conversation file store). Cloud account deletion is separate.
class LocalAgentDataPortabilityService {
  LocalAgentDataPortabilityService({
    required LocalBrain brain,
    Future<Map<String, dynamic>> Function()? exportConversations,
    Future<void> Function()? clearConversations,
  })  : _brain = brain,
        _exportConversations = exportConversations,
        _clearConversations = clearConversations;

  static const String exportVersion = '1.0';
  static const String exportFormat = 'pistisai-local-agent-data';
  static const String fileExtension = '.json';

  static String get filePrefix =>
      '${Brand.current.artifactPrefix}-local-agent-data';

  final LocalBrain _brain;
  final Future<Map<String, dynamic>> Function()? _exportConversations;
  final Future<void> Function()? _clearConversations;

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

    final verification = await verifyDeletion();
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

  /// Count remaining user-content rows; [isEmpty] is true when all are zero.
  Future<LocalAgentDataVerification> verifyDeletion() async {
    final allCounts = await _brain.countAllTableRows();
    final userCounts = <String, int>{
      for (final name in LocalBrain.userContentTableNames)
        name: allCounts[name] ?? 0,
    };
    final empty = userCounts.values.every((count) => count == 0);

    return LocalAgentDataVerification(
      checkedAt: DateTime.now(),
      remainingUserContentCounts: userCounts,
      allTableCounts: allCounts,
      isEmpty: empty,
    );
  }
}
