import 'dart:convert';
import 'package:pistisai/database/drift_local_brain.dart';
import 'package:drift/drift.dart';

/// Defines the available agent roles in the conscience system.
enum AgentRole {
  /// The primary agent — main interface with the user, coordinates all activity.
  primary,

  /// A secondary agent — assists with specific tasks under the primary.
  secondary,

  /// Orchestrates multi-agent workflows and manages task queues.
  coordinator,

  /// Reviews actions for risks, edge cases, and unintended consequences.
  reviewer;

  String get value => name;

  static AgentRole fromString(String value) {
    return AgentRole.values.firstWhere(
      (r) => r.name == value,
      orElse: () => AgentRole.secondary,
    );
  }
}

/// Service for managing persistent agent identities with roles.
///
/// This service provides CRUD operations for agent profiles (Benjamin, Harper,
/// Hermes, etc.), defines agent roles (primary, secondary, coordinator,
/// reviewer), and persists agent configurations including personality traits,
/// system prompts, and capabilities.
class AgentIdentityService {
  final LocalBrain _database;

  AgentIdentityService({
    required LocalBrain database,
  }) : _database = database;

  // ===========================================================================
  // CRUD Operations
  // ===========================================================================

  /// Create a new agent identity.
  Future<Map<String, dynamic>> createAgentIdentity({
    required String name,
    required AgentRole role,
    Map<String, double>? personalityTraits,
    String? systemPrompt,
    List<String>? capabilities,
    Map<String, dynamic>? avatarConfig,
    bool isActive = false,
  }) async {
    final id = name.toLowerCase().replaceAll(RegExp(r'\s+'), '-');
    final now = DateTime.now();

    await _database.insertAgentIdentity(AgentIdentitiesCompanion.insert(
      id: id,
      name: name,
      role: Value(role.value),
      personalityTraits: Value(
        personalityTraits != null ? jsonEncode(personalityTraits) : null,
      ),
      systemPrompt: Value(systemPrompt),
      capabilities: Value(
        capabilities != null ? jsonEncode(capabilities) : null,
      ),
      avatarConfig: Value(
        avatarConfig != null ? jsonEncode(avatarConfig) : null,
      ),
      isActive: Value(isActive),
      createdAt: Value(now),
      updatedAt: Value(now),
    ));

    return _identityToMap(AgentIdentity(
      id: id,
      name: name,
      role: role.value,
      personalityTraits:
          personalityTraits != null ? jsonEncode(personalityTraits) : null,
      systemPrompt: systemPrompt,
      capabilities:
          capabilities != null ? jsonEncode(capabilities) : null,
      avatarConfig:
          avatarConfig != null ? jsonEncode(avatarConfig) : null,
      isActive: isActive,
      createdAt: now,
      updatedAt: now,
    ));
  }

  /// Get all agent identities.
  Future<List<Map<String, dynamic>>> getAllAgentIdentities() async {
    final identities = await _database.getAllAgentIdentities();
    return identities.map(_identityToMap).toList();
  }

  /// Get a single agent identity by ID.
  Future<Map<String, dynamic>?> getAgentIdentity(String id) async {
    final identity = await _database.getAgentIdentityById(id);
    if (identity == null) return null;
    return _identityToMap(identity);
  }

  /// Update an existing agent identity.
  Future<Map<String, dynamic>> updateAgentIdentity({
    required String id,
    String? name,
    AgentRole? role,
    Map<String, double>? personalityTraits,
    String? systemPrompt,
    List<String>? capabilities,
    Map<String, dynamic>? avatarConfig,
    bool? isActive,
  }) async {
    final existing = await _database.getAgentIdentityById(id);
    if (existing == null) {
      throw StateError('Agent identity not found: $id');
    }

    final now = DateTime.now();
    final updated = AgentIdentitiesCompanion(
      id: Value(id),
      name: Value(name ?? existing.name),
      role: Value(role?.value ?? existing.role),
      personalityTraits: Value(
        personalityTraits != null
            ? jsonEncode(personalityTraits)
            : existing.personalityTraits,
      ),
      systemPrompt: Value(systemPrompt ?? existing.systemPrompt),
      capabilities: Value(
        capabilities != null
            ? jsonEncode(capabilities)
            : existing.capabilities,
      ),
      avatarConfig: Value(
        avatarConfig != null
            ? jsonEncode(avatarConfig)
            : existing.avatarConfig,
      ),
      isActive: Value(isActive ?? existing.isActive),
      updatedAt: Value(now),
    );

    await _database.updateAgentIdentity(updated);

    final result = await _database.getAgentIdentityById(id);
    return _identityToMap(result!);
  }

  /// Delete an agent identity.
  Future<void> deleteAgentIdentity(String id) async {
    final deleted = await _database.deleteAgentIdentity(id);
    if (deleted == 0) {
      throw StateError('Agent identity not found: $id');
    }
  }

  // ===========================================================================
  // Role-based Queries
  // ===========================================================================

  /// Get all agent identities with a specific role.
  Future<List<Map<String, dynamic>>> getAgentIdentitiesByRole(
      AgentRole role) async {
    final identities =
        await _database.getAgentIdentitiesByRole(role.value);
    return identities.map(_identityToMap).toList();
  }

  /// Get the primary (active) agent identity.
  Future<Map<String, dynamic>?> getPrimaryAgent() async {
    final identity = await _database.getPrimaryAgentIdentity();
    if (identity == null) return null;
    return _identityToMap(identity);
  }

  /// Get all active agent identities.
  Future<List<Map<String, dynamic>>> getActiveAgents() async {
    final identities = await _database.getActiveAgentIdentities();
    return identities.map(_identityToMap).toList();
  }

  /// Get reviewer agents (for conscience decisions).
  Future<List<Map<String, dynamic>>> getReviewerAgents() async {
    final identities = await _database.getAgentIdentitiesByRole('reviewer');
    return identities.map(_identityToMap).toList();
  }

  /// Get coordinator agents.
  Future<List<Map<String, dynamic>>> getCoordinatorAgents() async {
    final identities =
        await _database.getAgentIdentitiesByRole('coordinator');
    return identities.map(_identityToMap).toList();
  }

  // ===========================================================================
  // Activation Management
  // ===========================================================================

  /// Set an agent as the active primary agent.
  Future<void> setActiveAgent(String id) async {
    await _database.setActiveAgent(id);
  }

  /// Get the system prompt for a specific agent.
  Future<String?> getAgentSystemPrompt(String id) async {
    final identity = await _database.getAgentIdentityById(id);
    return identity?.systemPrompt;
  }

  /// Get the capabilities for a specific agent.
  Future<List<String>> getAgentCapabilities(String id) async {
    final identity = await _database.getAgentIdentityById(id);
    if (identity?.capabilities == null) return [];
    final decoded = jsonDecode(identity!.capabilities!);
    if (decoded is List) {
      return decoded.cast<String>();
    }
    return [];
  }

  /// Get the personality traits for a specific agent.
  Future<Map<String, double>> getAgentPersonalityTraits(String id) async {
    final identity = await _database.getAgentIdentityById(id);
    if (identity?.personalityTraits == null) return {};
    final decoded = jsonDecode(identity!.personalityTraits!);
    if (decoded is Map) {
      return decoded.map((k, v) => MapEntry(k.toString(), (v as num).toDouble()));
    }
    return {};
  }

  // ===========================================================================
  // Internal Helpers
  // ===========================================================================

  Map<String, dynamic> _identityToMap(AgentIdentity identity) {
    return {
      'id': identity.id,
      'name': identity.name,
      'role': identity.role,
      'personality_traits':
          identity.personalityTraits != null
              ? jsonDecode(identity.personalityTraits!)
              : null,
      'system_prompt': identity.systemPrompt,
      'capabilities':
          identity.capabilities != null
              ? jsonDecode(identity.capabilities!)
              : null,
      'avatar_config':
          identity.avatarConfig != null
              ? jsonDecode(identity.avatarConfig!)
              : null,
      'is_active': identity.isActive,
      'created_at': identity.createdAt.toIso8601String(),
      'updated_at': identity.updatedAt.toIso8601String(),
    };
  }
}
