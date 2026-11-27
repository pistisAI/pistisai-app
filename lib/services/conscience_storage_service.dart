import 'dart:convert';
import 'package:pistisai/database/drift_local_brain.dart';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'agent_action_audit_service.dart';
import 'approval_gate_service.dart';

/// Audit logger for [ApprovalGateService] that stores the user's own
/// decisions through the in-process [ConscienceStorageService.recordHumanApproval].
ApprovalAuditLogger conscienceApprovalAuditLogger(
    ConscienceStorageService storage) {
  return (entry) async {
    await storage.recordHumanApproval(
      action:
          '${entry.action.category.name}: ${entry.action.title} — ${entry.action.summary}',
      riskLevel: 'critical',
      approved: entry.verdict == ApprovalVerdict.approved,
      reasoning: entry.note ?? 'Human approval gate',
    );
  };
}

/// Why a conscience decision write was refused.
enum ConscienceIntegrityViolation {
  /// The verdict is not one of [ConscienceStorageService.allowedVerdicts].
  invalidVerdict,

  /// The reviewer name is reserved for the human user (ApprovalGateService).
  reservedReviewer,

  /// The decision already has a final verdict or was decided by the user.
  decisionLocked,
}

/// Thrown when a write would forge or change a human approval record.
class ConscienceIntegrityException implements Exception {
  ConscienceIntegrityException(this.violation, this.message);

  final ConscienceIntegrityViolation violation;
  final String message;

  @override
  String toString() => 'ConscienceIntegrityException($violation): $message';
}

class ConscienceStorageService {
  /// Verdicts a reviewer may record.
  static const allowedVerdicts = {'APPROVED', 'DENIED', 'HOLD', 'QUESTION'};

  /// Verdicts after which a decision can no longer be changed.
  static const finalVerdicts = {'APPROVED', 'DENIED'};

  /// Reviewer names that only in-process human approval code may write
  /// (see [recordHumanApproval]). AGENTS.md: a person approves critical actions.
  static const reservedReviewers = {'user'};

  static bool isReservedReviewer(String? reviewer) =>
      reviewer != null &&
      reservedReviewers.contains(reviewer.trim().toLowerCase());

  /// Returns the upper-case verdict, or null when [verdict] is not allowed.
  static String? normalizeVerdict(String verdict) {
    final normalized = verdict.trim().toUpperCase();
    return allowedVerdicts.contains(normalized) ? normalized : null;
  }

  final LocalBrain _database;
  final AgentActionAuditService? _audit;
  final Uuid _uuid = const Uuid();

  ConscienceStorageService({
    required LocalBrain database,
    AgentActionAuditService? audit,
  })  : _database = database,
        _audit = audit;

  Future<Map<String, dynamic>> writeThought({
    required String agent,
    required String thoughtType,
    required String content,
    String channel = 'general',
    Map<String, dynamic>? metadata,
  }) async {
    final id = _uuid.v4();
    final now = DateTime.now();

    await _database.insertThought(AgentThoughtsCompanion.insert(
      id: id,
      timestamp: Value(now),
      channel: Value(channel),
      agent: agent,
      thoughtType: thoughtType,
      content: content,
      metadata: Value(metadata != null ? jsonEncode(metadata) : null),
    ));

    await _audit?.record(
      action: 'conscience.write_thought',
      dataTouched: 'agent_thoughts:$id',
      authorizationStatus: AgentAuditAuthorization.autoAllowed,
      outcome: AgentAuditOutcome.success,
      agentId: agent,
      authorizedBy: agent,
      details: {
        'thought_type': thoughtType,
        'channel': channel,
      },
    );

    return {
      'id': id,
      'timestamp': now.toIso8601String(),
      'channel': channel,
      'agent': agent,
      'thought_type': thoughtType,
      'content': content,
      'metadata': metadata,
    };
  }

  Future<List<Map<String, dynamic>>> getThoughts({
    String? agent,
    String? channel,
    String? thoughtType,
    int limit = 50,
  }) async {
    List<AgentThought> thoughts;

    if (agent != null) {
      thoughts = await _database.getThoughtsByAgent(agent, limit: limit);
    } else if (channel != null) {
      thoughts = await _database.getThoughtsByChannel(channel, limit: limit);
    } else if (thoughtType != null) {
      thoughts = await _database.getThoughtsByType(thoughtType, limit: limit);
    } else {
      thoughts = await _database.getRecentThoughts(limit: limit);
    }

    await _audit?.record(
      action: 'conscience.read_thoughts',
      dataTouched: 'agent_thoughts',
      authorizationStatus: AgentAuditAuthorization.autoAllowed,
      outcome: AgentAuditOutcome.success,
      agentId: agent,
      details: {
        'count': thoughts.length,
        'channel': channel,
        'thought_type': thoughtType,
      },
    );

    return thoughts.map(_thoughtToMap).toList();
  }

  /// Records a decision proposed or reviewed by an agent.
  ///
  /// Refuses reviewer names reserved for the human user and unknown verdicts:
  /// this path is reachable from HTTP callers on the router.
  Future<Map<String, dynamic>> writeDecision({
    required String action,
    required String riskLevel,
    String? verdict,
    String? reviewer,
    String? reasoning,
  }) async {
    if (isReservedReviewer(reviewer)) {
      throw ConscienceIntegrityException(
        ConscienceIntegrityViolation.reservedReviewer,
        'Reviewer name is reserved for the user',
      );
    }
    String? normalizedVerdict;
    if (verdict != null) {
      normalizedVerdict = normalizeVerdict(verdict);
      if (normalizedVerdict == null) {
        throw ConscienceIntegrityException(
          ConscienceIntegrityViolation.invalidVerdict,
          'Verdict must be one of ${allowedVerdicts.join(', ')}',
        );
      }
    }
    return _insertDecision(
      action: action,
      riskLevel: riskLevel,
      verdict: normalizedVerdict,
      reviewer: reviewer,
      reasoning: reasoning,
    );
  }

  /// Records the human user's own approve/deny decision from the in-app
  /// approval gate. In-process only: no HTTP handler calls this.
  Future<Map<String, dynamic>> recordHumanApproval({
    required String action,
    required String riskLevel,
    required bool approved,
    String? reasoning,
  }) {
    return _insertDecision(
      action: action,
      riskLevel: riskLevel,
      verdict: approved ? 'APPROVED' : 'DENIED',
      reviewer: 'user',
      reasoning: reasoning,
    );
  }

  Future<Map<String, dynamic>> _insertDecision({
    required String action,
    required String riskLevel,
    String? verdict,
    String? reviewer,
    String? reasoning,
  }) async {
    final id = _uuid.v4();
    final now = DateTime.now();
    final status = verdict != null ? 'reviewed' : 'pending';

    await _database.insertDecision(ConscienceDecisionsCompanion.insert(
      id: id,
      timestamp: Value(now),
      action: action,
      riskLevel: riskLevel,
      verdict: Value(verdict),
      reviewer: Value(reviewer),
      reasoning: Value(reasoning),
      status: Value(status),
    ));

    await _audit?.record(
      action: 'conscience.write_decision',
      dataTouched: 'conscience_decisions:$id',
      authorizationStatus: verdict == null
          ? AgentAuditAuthorization.pending
          : _authFromVerdict(verdict),
      outcome: AgentAuditOutcome.success,
      agentId: reviewer,
      authorizedBy: reviewer,
      details: {
        'proposed_action': action,
        'risk_level': riskLevel,
        'verdict': verdict,
        'status': status,
      },
    );

    return {
      'id': id,
      'timestamp': now.toIso8601String(),
      'action': action,
      'risk_level': riskLevel,
      'verdict': verdict,
      'reviewer': reviewer,
      'reasoning': reasoning,
      'status': status,
    };
  }

  Future<Map<String, dynamic>> submitDecisionVerdict({
    required String decisionId,
    required String verdict,
    required String reviewer,
    required String reasoning,
  }) async {
    final normalizedVerdict = normalizeVerdict(verdict);
    if (normalizedVerdict == null) {
      throw ConscienceIntegrityException(
        ConscienceIntegrityViolation.invalidVerdict,
        'Verdict must be one of ${allowedVerdicts.join(', ')}',
      );
    }
    if (isReservedReviewer(reviewer)) {
      throw ConscienceIntegrityException(
        ConscienceIntegrityViolation.reservedReviewer,
        'Reviewer name is reserved for the user',
      );
    }

    // Read before writing: a decision the user made, or one that already has
    // a final verdict, must not be changed afterwards.
    final existing = await _database.getDecisionById(decisionId);
    if (existing != null) {
      final existingVerdict = existing.verdict?.trim().toUpperCase();
      if (isReservedReviewer(existing.reviewer) ||
          (existingVerdict != null &&
              finalVerdicts.contains(existingVerdict))) {
        await _audit?.record(
          action: 'conscience.submit_verdict',
          dataTouched: 'conscience_decisions:$decisionId',
          authorizationStatus: AgentAuditAuthorization.denied,
          outcome: AgentAuditOutcome.failure,
          agentId: reviewer,
          authorizedBy: reviewer,
          details: {'reason': 'decision_locked'},
        );
        throw ConscienceIntegrityException(
          ConscienceIntegrityViolation.decisionLocked,
          'Decision already has a final verdict',
        );
      }
      await _database.updateDecisionVerdict(
          decisionId, normalizedVerdict, reviewer, reasoning);
    }

    final decision =
        existing == null ? null : await _database.getDecisionById(decisionId);
    if (decision == null) {
      await _audit?.record(
        action: 'conscience.submit_verdict',
        dataTouched: 'conscience_decisions:$decisionId',
        authorizationStatus: AgentAuditAuthorization.denied,
        outcome: AgentAuditOutcome.failure,
        agentId: reviewer,
        authorizedBy: reviewer,
        details: {'reason': 'decision_not_found'},
      );
      throw StateError('Decision not found: $decisionId');
    }

    await _audit?.record(
      action: 'conscience.submit_verdict',
      dataTouched: 'conscience_decisions:$decisionId',
      authorizationStatus: _authFromVerdict(normalizedVerdict),
      outcome: AgentAuditOutcome.success,
      agentId: reviewer,
      authorizedBy: reviewer,
      details: {
        'verdict': normalizedVerdict,
        'proposed_action': decision.action,
        'risk_level': decision.riskLevel,
      },
    );

    return _decisionToMap(decision);
  }

  Future<List<Map<String, dynamic>>> getDecisions({
    String? status,
    String? riskLevel,
    int limit = 50,
  }) async {
    List<ConscienceDecision> decisions;

    if (status != null) {
      decisions = await _database.getDecisionsByStatus(status, limit: limit);
    } else if (riskLevel != null) {
      decisions =
          await _database.getDecisionsByRiskLevel(riskLevel, limit: limit);
    } else {
      decisions = await _database.getAllDecisions(limit: limit);
    }

    await _audit?.record(
      action: 'conscience.read_decisions',
      dataTouched: 'conscience_decisions',
      authorizationStatus: AgentAuditAuthorization.autoAllowed,
      outcome: AgentAuditOutcome.success,
      details: {
        'count': decisions.length,
        'status': status,
        'risk_level': riskLevel,
      },
    );

    return decisions.map(_decisionToMap).toList();
  }

  String _authFromVerdict(String verdict) {
    switch (verdict.toUpperCase()) {
      case 'APPROVED':
        return AgentAuditAuthorization.authorized;
      case 'DENIED':
        return AgentAuditAuthorization.denied;
      case 'HOLD':
      case 'QUESTION':
        return AgentAuditAuthorization.pending;
      default:
        return AgentAuditAuthorization.pending;
    }
  }

  Map<String, dynamic> _thoughtToMap(AgentThought thought) {
    return {
      'id': thought.id,
      'timestamp': thought.timestamp.toIso8601String(),
      'channel': thought.channel,
      'agent': thought.agent,
      'thought_type': thought.thoughtType,
      'content': thought.content,
      'metadata':
          thought.metadata != null ? jsonDecode(thought.metadata!) : null,
    };
  }

  Map<String, dynamic> _decisionToMap(ConscienceDecision decision) {
    return {
      'id': decision.id,
      'timestamp': decision.timestamp.toIso8601String(),
      'action': decision.action,
      'risk_level': decision.riskLevel,
      'verdict': decision.verdict,
      'reviewer': decision.reviewer,
      'reasoning': decision.reasoning,
      'status': decision.status,
    };
  }
}
