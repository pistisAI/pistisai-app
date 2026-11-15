import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

/// Categories used to mark agent/workflow actions that leave data or call
/// integrations. Workflows can also force approval via [CriticalAction.requiresApproval]
/// or [ApprovalGateService.registerCriticalActionType].
enum CriticalActionCategory {
  dataExport,
  integrationCall,
  custom,
}

/// What the agent or workflow wants to do before it runs.
@immutable
class CriticalAction {
  CriticalAction({
    required this.category,
    required this.title,
    required this.summary,
    this.details = const <String, dynamic>{},
    this.workflowId,
    this.actionType,
    this.requiresApproval = false,
    String? id,
    DateTime? createdAt,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now();

  final String id;
  final CriticalActionCategory category;
  final String title;
  final String summary;
  final Map<String, dynamic> details;
  final String? workflowId;
  final String? actionType;
  final bool requiresApproval;
  final DateTime createdAt;
}

enum ApprovalVerdict { approved, denied }

@immutable
class ApprovalDecision {
  const ApprovalDecision({
    required this.requestId,
    required this.verdict,
    required this.decidedAt,
    this.note,
  });

  final String requestId;
  final ApprovalVerdict verdict;
  final DateTime decidedAt;
  final String? note;
}

/// One logged approval decision for the local audit trail.
@immutable
class ApprovalAuditEntry {
  const ApprovalAuditEntry({
    required this.action,
    required this.verdict,
    required this.decidedAt,
    this.note,
  });

  final CriticalAction action;
  final ApprovalVerdict verdict;
  final DateTime decidedAt;
  final String? note;
}

typedef ApprovalAuditLogger = Future<void> Function(ApprovalAuditEntry entry);

class ApprovalDeniedException implements Exception {
  ApprovalDeniedException(this.action, {this.note});

  final CriticalAction action;
  final String? note;

  @override
  String toString() =>
      'ApprovalDeniedException: "${action.title}" was denied'
      '${note == null || note!.isEmpty ? '' : ' ($note)'}';
}

/// Generic human-in-the-loop gate for critical agent/workflow actions.
///
/// Callers pause on [requestApproval] / [runCritical] until the UI (or a test)
/// resolves the pending request. Every decision is appended to [auditTrail]
/// and optionally forwarded to [auditLogger] (e.g. conscience storage).
class ApprovalGateService extends ChangeNotifier {
  ApprovalGateService({
    ApprovalAuditLogger? auditLogger,
    Uuid? uuid,
    Set<CriticalActionCategory>? defaultCriticalCategories,
  })  : _auditLogger = auditLogger,
        _uuid = uuid ?? const Uuid(),
        _criticalCategories = {
          CriticalActionCategory.dataExport,
          CriticalActionCategory.integrationCall,
          ...?defaultCriticalCategories,
        };

  final ApprovalAuditLogger? _auditLogger;
  final Uuid _uuid;
  final Set<CriticalActionCategory> _criticalCategories;
  final Set<String> _criticalActionTypes = <String>{};
  final Map<String, _PendingApproval> _pending = <String, _PendingApproval>{};
  final List<ApprovalAuditEntry> _auditTrail = <ApprovalAuditEntry>[];

  List<CriticalAction> get pendingRequests =>
      List.unmodifiable(_pending.values.map((p) => p.action));

  List<ApprovalAuditEntry> get auditTrail => List.unmodifiable(_auditTrail);

  void registerCriticalCategory(CriticalActionCategory category) {
    _criticalCategories.add(category);
  }

  void registerCriticalActionType(String actionType) {
    final trimmed = actionType.trim();
    if (trimmed.isEmpty) return;
    _criticalActionTypes.add(trimmed);
  }

  bool requiresApproval(CriticalAction action) {
    if (action.requiresApproval) return true;
    if (_criticalCategories.contains(action.category)) return true;
    final type = action.actionType;
    if (type != null && _criticalActionTypes.contains(type)) return true;
    return false;
  }

  /// Pause until the user approves or denies. Non-critical actions auto-approve.
  Future<ApprovalDecision> requestApproval(CriticalAction action) async {
    if (!requiresApproval(action)) {
      final decision = ApprovalDecision(
        requestId: action.id,
        verdict: ApprovalVerdict.approved,
        decidedAt: DateTime.now(),
        note: 'auto-approved (not marked critical)',
      );
      _recordDecision(action, decision);
      return decision;
    }

    final completer = Completer<ApprovalDecision>();
    _pending[action.id] = _PendingApproval(action: action, completer: completer);
    notifyListeners();
    return completer.future;
  }

  /// Resolve a pending request. No-op if the id is unknown or already resolved.
  void resolve(
    String requestId,
    ApprovalVerdict verdict, {
    String? note,
  }) {
    final pending = _pending.remove(requestId);
    if (pending == null) return;

    final decision = ApprovalDecision(
      requestId: requestId,
      verdict: verdict,
      decidedAt: DateTime.now(),
      note: note,
    );
    _recordDecision(pending.action, decision);
    if (!pending.completer.isCompleted) {
      pending.completer.complete(decision);
    }
  }

  /// Run [execute] only after approval. Throws [ApprovalDeniedException] if denied.
  Future<T> runCritical<T>({
    required CriticalAction action,
    required Future<T> Function() execute,
  }) async {
    final decision = await requestApproval(action);
    if (decision.verdict != ApprovalVerdict.approved) {
      throw ApprovalDeniedException(action, note: decision.note);
    }
    return execute();
  }

  /// Helper for workflows that only have a description and category.
  CriticalAction createAction({
    required CriticalActionCategory category,
    required String title,
    required String summary,
    Map<String, dynamic> details = const <String, dynamic>{},
    String? workflowId,
    String? actionType,
    bool requiresApproval = false,
  }) {
    return CriticalAction(
      id: _uuid.v4(),
      category: category,
      title: title,
      summary: summary,
      details: details,
      workflowId: workflowId,
      actionType: actionType,
      requiresApproval: requiresApproval,
    );
  }

  void _recordDecision(CriticalAction action, ApprovalDecision decision) {
    final entry = ApprovalAuditEntry(
      action: action,
      verdict: decision.verdict,
      decidedAt: decision.decidedAt,
      note: decision.note,
    );
    _auditTrail.add(entry);
    notifyListeners();

    final logger = _auditLogger;
    if (logger != null) {
      unawaited(() async {
        try {
          await logger(entry);
        } catch (e) {
          debugPrint('[ApprovalGate] audit logger failed: $e');
        }
      }());
    }
  }
}

class _PendingApproval {
  _PendingApproval({required this.action, required this.completer});

  final CriticalAction action;
  final Completer<ApprovalDecision> completer;
}
