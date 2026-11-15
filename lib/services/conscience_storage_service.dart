import 'dart:convert';
import 'package:pistisai/database/drift_local_brain.dart';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'agent_action_audit_service.dart';

class ConscienceStorageService {
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

  Future<Map<String, dynamic>> writeDecision({
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
    await _database.updateDecisionVerdict(
        decisionId, verdict, reviewer, reasoning);

    final decision = await _database.getDecisionById(decisionId);
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
      authorizationStatus: _authFromVerdict(verdict),
      outcome: AgentAuditOutcome.success,
      agentId: reviewer,
      authorizedBy: reviewer,
      details: {
        'verdict': verdict,
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
