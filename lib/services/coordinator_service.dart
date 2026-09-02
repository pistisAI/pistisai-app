import 'package:drift/drift.dart';
import 'package:pistisai/database/drift_local_brain.dart';
import 'package:pistisai/services/conscience_storage_service.dart';
import 'package:uuid/uuid.dart';

/// Result of a consensus evaluation
class ConsensusResult {
  final String coordinatorId;
  final String decisionId;
  final String status; // consensus, conflict, escalated
  final String? consensusVerdict;
  final String? consensusReasoning;
  final String? conflictType;
  final String? resolutionStrategy;
  final Map<String, String> votes; // agent -> vote
  final int totalVotes;
  final int approveCount;
  final int questionCount;
  final int holdCount;
  final int denyCount;

  ConsensusResult({
    required this.coordinatorId,
    required this.decisionId,
    required this.status,
    this.consensusVerdict,
    this.consensusReasoning,
    this.conflictType,
    this.resolutionStrategy,
    required this.votes,
    required this.totalVotes,
    required this.approveCount,
    required this.questionCount,
    required this.holdCount,
    required this.denyCount,
  });

  Map<String, dynamic> toMap() => {
        'coordinator_id': coordinatorId,
        'decision_id': decisionId,
        'status': status,
        'consensus_verdict': consensusVerdict,
        'consensus_reasoning': consensusReasoning,
        'conflict_type': conflictType,
        'resolution_strategy': resolutionStrategy,
        'votes': votes,
        'total_votes': totalVotes,
        'approve_count': approveCount,
        'question_count': questionCount,
        'hold_count': holdCount,
        'deny_count': denyCount,
      };
}

/// CoordinatorService mediates between multiple agent identities to reach
/// consensus on conscience decisions and resolve conflicts.
///
/// Phase 4 of the Conscience System implements:
/// - Consensus logic: when multiple agents evaluate the same decision,
///   reach a consensus
/// - Conflict resolution: majority vote, escalation, user mediation
/// - Coordinator state tracking in the conscience database
class CoordinatorService {
  final LocalBrain _database;
  final ConscienceStorageService _conscienceStorage;
  final Uuid _uuid = const Uuid();

  /// The set of known agent identities that can participate in coordination.
  static const List<String> knownAgents = [
    'hermes',
    'benjamin',
    'harper',
  ];

  CoordinatorService({
    required LocalBrain database,
    required ConscienceStorageService conscienceStorage,
  })  : _database = database,
        _conscienceStorage = conscienceStorage;

  // ===========================================================================
  // COORDINATOR SESSION MANAGEMENT
  // ===========================================================================

  /// Open a new coordinator session for a given decision.
  /// Returns the coordinator state ID.
  Future<String> openCoordinatorSession({
    required String decisionId,
    required String action,
    required String riskLevel,
  }) async {
    final id = _uuid.v4();

    await _database.insertCoordinatorState(CoordinatorStatesCompanion.insert(
      id: id,
      decisionId: decisionId,
      action: action,
      riskLevel: riskLevel,
    ));

    return id;
  }

  /// Cast a vote in a coordinator session.
  /// Returns the updated consensus result.
  Future<ConsensusResult> castVote({
    required String coordinatorId,
    required String agent,
    required String vote,
    String? reasoning,
  }) async {
    // Validate the vote
    if (!['APPROVED', 'QUESTION', 'HOLD', 'DENIED'].contains(vote)) {
      throw ArgumentError('Invalid vote: $vote. Must be one of: '
          'APPROVED, QUESTION, HOLD, DENIED');
    }

    // Validate the agent
    if (!knownAgents.contains(agent)) {
      throw ArgumentError('Unknown agent: $agent. Must be one of: '
          '${knownAgents.join(', ')}');
    }

    // Get the coordinator state
    final state = await _database.getCoordinatorStateById(coordinatorId);
    if (state == null) {
      throw StateError('Coordinator session not found: $coordinatorId');
    }

    if (state.status != 'open') {
      throw StateError(
          'Coordinator session $coordinatorId is already closed (${state.status})');
    }

    // Check if this agent already voted
    final existingVotes = await _database.getCoordinatorVotes(coordinatorId);
    if (existingVotes.any((v) => v.agent == agent)) {
      throw StateError('Agent $agent has already voted in session '
          '$coordinatorId');
    }

    // Record the vote
    await _database.insertCoordinatorVote(CoordinatorVotesCompanion.insert(
      id: _uuid.v4(),
      coordinatorId: coordinatorId,
      agent: agent,
      vote: vote,
      reasoning: Value(reasoning),
    ));

    // Recalculate tallies
    final allVotes = await _database.getCoordinatorVotes(coordinatorId);
    return _evaluateConsensus(state, allVotes);
  }

  // ===========================================================================
  // CONSENSUS EVALUATION
  // ===========================================================================

  /// Evaluate whether consensus has been reached among the votes.
  /// Updates the coordinator state and returns the result.
  Future<ConsensusResult> _evaluateConsensus(
    CoordinatorState state,
    List<CoordinatorVote> votes,
  ) async {
    final voteMap = <String, String>{};
    int approveCount = 0;
    int questionCount = 0;
    int holdCount = 0;
    int denyCount = 0;

    for (final vote in votes) {
      voteMap[vote.agent] = vote.vote;
      switch (vote.vote) {
        case 'APPROVED':
          approveCount++;
        case 'QUESTION':
          questionCount++;
        case 'HOLD':
          holdCount++;
        case 'DENIED':
          denyCount++;
      }
    }

    final totalVotes = votes.length;
    final now = DateTime.now();

    // Determine the resolution strategy based on risk level
    final resolutionStrategy = _determineResolutionStrategy(
      state.riskLevel,
      totalVotes,
    );

    // Check for consensus
    final consensusResult = _checkConsensus(
      approveCount: approveCount,
      questionCount: questionCount,
      holdCount: holdCount,
      denyCount: denyCount,
      totalVotes: totalVotes,
      riskLevel: state.riskLevel,
    );

    String status;
    String? consensusVerdict;
    String? consensusReasoning;
    String? conflictType;

    if (consensusResult != null) {
      // Consensus reached
      status = 'consensus';
      consensusVerdict = consensusResult['verdict'];
      consensusReasoning = consensusResult['reasoning'];

      // Update the underlying decision with the consensus verdict
      await _conscienceStorage.submitDecisionVerdict(
        decisionId: state.decisionId,
        verdict: consensusVerdict!,
        reviewer: 'coordinator',
        reasoning: consensusReasoning ?? 'No reasoning provided',
      );
    } else if (resolutionStrategy == 'escalation') {
      // Escalation needed - conflict cannot be resolved automatically
      status = 'escalated';
      conflictType = _determineConflictType(
        approveCount: approveCount,
        questionCount: questionCount,
        holdCount: holdCount,
        denyCount: denyCount,
        totalVotes: totalVotes,
      );
    } else {
      // Conflict detected - apply majority vote
      status = 'conflict';
      conflictType = _determineConflictType(
        approveCount: approveCount,
        questionCount: questionCount,
        holdCount: holdCount,
        denyCount: denyCount,
        totalVotes: totalVotes,
      );

      // Apply majority vote resolution
      final majorityResult = _applyMajorityVote(
        approveCount: approveCount,
        questionCount: questionCount,
        holdCount: holdCount,
        denyCount: denyCount,
        totalVotes: totalVotes,
      );

      if (majorityResult != null) {
        consensusVerdict = majorityResult['verdict'];
        consensusReasoning = majorityResult['reasoning'];

        // Update the underlying decision
        await _conscienceStorage.submitDecisionVerdict(
          decisionId: state.decisionId,
          verdict: consensusVerdict ?? 'DENIED',
          reviewer: 'coordinator',
          reasoning: consensusReasoning ?? 'Majority vote resolution',
        );
      }
    }

    // Update the coordinator state
    await _database.updateCoordinatorState(
      state.id,
      CoordinatorStatesCompanion(
        updatedAt: Value(now),
        status: Value(status),
        consensusVerdict: Value(consensusVerdict),
        consensusReasoning: Value(consensusReasoning),
        conflictType: Value(conflictType),
        resolutionStrategy: Value(resolutionStrategy),
        totalVotes: Value(totalVotes),
        approveCount: Value(approveCount),
        questionCount: Value(questionCount),
        holdCount: Value(holdCount),
        denyCount: Value(denyCount),
      ),
    );

    return ConsensusResult(
      coordinatorId: state.id,
      decisionId: state.decisionId,
      status: status,
      consensusVerdict: consensusVerdict,
      consensusReasoning: consensusReasoning,
      conflictType: conflictType,
      resolutionStrategy: resolutionStrategy,
      votes: voteMap,
      totalVotes: totalVotes,
      approveCount: approveCount,
      questionCount: questionCount,
      holdCount: holdCount,
      denyCount: denyCount,
    );
  }

  /// Check if a clear consensus exists among the votes.
  /// Returns null if no consensus, or a map with 'verdict' and 'reasoning'.
  Map<String, String>? _checkConsensus({
    required int approveCount,
    required int questionCount,
    required int holdCount,
    required int denyCount,
    required int totalVotes,
    required String riskLevel,
  }) {
    // Unanimous consensus - all agents agree
    if (totalVotes > 0) {
      if (approveCount == totalVotes) {
        return {
          'verdict': 'APPROVED',
          'reasoning': 'Unanimous approval by all agents.',
        };
      }
      if (denyCount == totalVotes) {
        return {
          'verdict': 'DENIED',
          'reasoning': 'Unanimous denial by all agents.',
        };
      }
    }

    // Super-majority (2/3+) for high/critical risk
    if (riskLevel == 'high' || riskLevel == 'critical') {
      final superMajority = (totalVotes * 2 / 3).ceil();
      if (approveCount >= superMajority) {
        return {
          'verdict': 'APPROVED',
          'reasoning': 'Super-majority approval ($approveCount/$totalVotes).',
        };
      }
      if (denyCount >= superMajority) {
        return {
          'verdict': 'DENIED',
          'reasoning': 'Super-majority denial ($denyCount/$totalVotes).',
        };
      }
    }

    // Simple majority for low/medium risk
    if (riskLevel == 'low' || riskLevel == 'medium') {
      final majority = (totalVotes / 2).ceil();
      if (approveCount >= majority && approveCount > denyCount) {
        return {
          'verdict': 'APPROVED',
          'reasoning':
              'Majority approval ($approveCount/$totalVotes votes).',
        };
      }
      if (denyCount >= majority && denyCount > approveCount) {
        return {
          'verdict': 'DENIED',
          'reasoning': 'Majority denial ($denyCount/$totalVotes votes).',
        };
      }
    }

    return null;
  }

  // ===========================================================================
  // CONFLICT RESOLUTION
  // ===========================================================================

  /// Determine the resolution strategy based on risk level and vote count.
  String _determineResolutionStrategy(String riskLevel, int totalVotes) {
    // Critical risk actions always require escalation to user
    if (riskLevel == 'critical') {
      return 'escalation';
    }

    // High risk with all agents voting needs escalation if no consensus
    if (riskLevel == 'high' && totalVotes >= knownAgents.length) {
      return 'escalation';
    }

    // Otherwise, use majority vote
    return 'majority_vote';
  }

  /// Determine the type of conflict.
  String _determineConflictType({
    required int approveCount,
    required int questionCount,
    required int holdCount,
    required int denyCount,
    required int totalVotes,
  }) {
    if (approveCount == denyCount && approveCount > 0) {
      return 'tie';
    }
    if (questionCount > 0 && approveCount == 0 && denyCount == 0) {
      return 'all_question';
    }
    if (holdCount > 0 && approveCount == 0 && denyCount == 0) {
      return 'all_hold';
    }
    return 'majority_split';
  }

  /// Apply majority vote resolution.
  /// Returns the winning verdict or null if no clear winner.
  Map<String, String>? _applyMajorityVote({
    required int approveCount,
    required int questionCount,
    required int holdCount,
    required int denyCount,
    required int totalVotes,
  }) {
    // Build a map of vote -> count
    final voteCounts = <String, int>{
      'APPROVED': approveCount,
      'QUESTION': questionCount,
      'HOLD': holdCount,
      'DENIED': denyCount,
    };

    // Sort by count descending
    final sorted = voteCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final top = sorted.first;
    final runnerUp = sorted.length > 1 ? sorted[1] : null;

    // Must have a clear winner (not a tie)
    if (runnerUp != null && top.value == runnerUp.value) {
      // Tie - cannot resolve by majority
      return null;
    }

    if (top.value == 0) {
      return null;
    }

    String reasoning;
    switch (top.key) {
      case 'APPROVED':
        reasoning =
            'Majority vote resolved to APPROVED ($approveCount/$totalVotes).';
      case 'DENIED':
        reasoning =
            'Majority vote resolved to DENIED ($denyCount/$totalVotes).';
      case 'QUESTION':
        reasoning =
            'Majority vote resolved to QUESTION ($questionCount/$totalVotes).';
      case 'HOLD':
        reasoning =
            'Majority vote resolved to HOLD ($holdCount/$totalVotes).';
      default:
        reasoning = 'Majority vote resolved to ${top.key}.';
    }

    return {
      'verdict': top.key,
      'reasoning': reasoning,
    };
  }

  // ===========================================================================
  // USER MEDIATION
  // ===========================================================================

  /// Resolve a conflict via user mediation.
  /// The user provides the final verdict and reasoning.
  Future<ConsensusResult> resolveViaUserMediation({
    required String coordinatorId,
    required String verdict,
    required String reasoning,
  }) async {
    // Validate the verdict
    if (!['APPROVED', 'QUESTION', 'HOLD', 'DENIED'].contains(verdict)) {
      throw ArgumentError('Invalid verdict: $verdict. Must be one of: '
          'APPROVED, QUESTION, HOLD, DENIED');
    }

    final state = await _database.getCoordinatorStateById(coordinatorId);
    if (state == null) {
      throw StateError('Coordinator session not found: $coordinatorId');
    }

    if (state.status != 'conflict' && state.status != 'escalated') {
      throw StateError(
          'Coordinator session $coordinatorId is not in a resolvable state '
          '(current: ${state.status})');
    }

    final now = DateTime.now();
    final allVotes = await _database.getCoordinatorVotes(coordinatorId);
    final voteMap = <String, String>{};
    for (final vote in allVotes) {
      voteMap[vote.agent] = vote.vote;
    }

    // Update the coordinator state
    await _database.updateCoordinatorState(
      state.id,
      CoordinatorStatesCompanion(
        updatedAt: Value(now),
        status: const Value('resolved'),
        consensusVerdict: Value(verdict),
        consensusReasoning: Value(reasoning),
        resolvedBy: const Value('user'),
        resolutionStrategy: const Value('user_mediation'),
      ),
    );

    // Update the underlying decision
    await _conscienceStorage.submitDecisionVerdict(
      decisionId: state.decisionId,
      verdict: verdict,
      reviewer: 'user',
      reasoning: reasoning,
    );

    return ConsensusResult(
      coordinatorId: state.id,
      decisionId: state.decisionId,
      status: 'resolved',
      consensusVerdict: verdict,
      consensusReasoning: reasoning,
      conflictType: state.conflictType,
      resolutionStrategy: 'user_mediation',
      votes: voteMap,
      totalVotes: allVotes.length,
      approveCount: state.approveCount,
      questionCount: state.questionCount,
      holdCount: state.holdCount,
      denyCount: state.denyCount,
    );
  }

  // ===========================================================================
  // QUERY METHODS
  // ===========================================================================

  /// Get the current state of a coordinator session.
  Future<Map<String, dynamic>?> getCoordinatorState(String coordinatorId) async {
    final state = await _database.getCoordinatorStateById(coordinatorId);
    if (state == null) return null;

    final votes = await _database.getCoordinatorVotes(coordinatorId);
    final voteMap = <String, String>{};
    for (final vote in votes) {
      voteMap[vote.agent] = vote.vote;
    }

    return {
      'id': state.id,
      'decision_id': state.decisionId,
      'action': state.action,
      'risk_level': state.riskLevel,
      'status': state.status,
      'consensus_verdict': state.consensusVerdict,
      'consensus_reasoning': state.consensusReasoning,
      'conflict_type': state.conflictType,
      'resolution_strategy': state.resolutionStrategy,
      'resolved_by': state.resolvedBy,
      'total_votes': state.totalVotes,
      'approve_count': state.approveCount,
      'question_count': state.questionCount,
      'hold_count': state.holdCount,
      'deny_count': state.denyCount,
      'votes': voteMap,
      'created_at': state.createdAt.toIso8601String(),
      'updated_at': state.updatedAt.toIso8601String(),
    };
  }

  /// Get all open coordinator sessions.
  Future<List<Map<String, dynamic>>> getOpenSessions({int limit = 50}) async {
    final states = await _database.getOpenCoordinatorStates(limit: limit);
    return states.map(_stateToMap).toList();
  }

  /// Get coordinator sessions by status.
  Future<List<Map<String, dynamic>>> getSessionsByStatus(
    String status, {
    int limit = 50,
  }) async {
    final states =
        await _database.getCoordinatorStatesByStatus(status, limit: limit);
    return states.map(_stateToMap).toList();
  }

  /// Get all coordinator sessions.
  Future<List<Map<String, dynamic>>> getAllSessions({int limit = 50}) async {
    final states = await _database.getAllCoordinatorStates(limit: limit);
    return states.map(_stateToMap).toList();
  }

  Map<String, dynamic> _stateToMap(CoordinatorState state) {
    return {
      'id': state.id,
      'decision_id': state.decisionId,
      'action': state.action,
      'risk_level': state.riskLevel,
      'status': state.status,
      'consensus_verdict': state.consensusVerdict,
      'consensus_reasoning': state.consensusReasoning,
      'conflict_type': state.conflictType,
      'resolution_strategy': state.resolutionStrategy,
      'resolved_by': state.resolvedBy,
      'total_votes': state.totalVotes,
      'approve_count': state.approveCount,
      'question_count': state.questionCount,
      'hold_count': state.holdCount,
      'deny_count': state.denyCount,
      'created_at': state.createdAt.toIso8601String(),
      'updated_at': state.updatedAt.toIso8601String(),
    };
  }
}
