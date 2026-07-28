import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import 'agent_lifecycle_service.dart';
import 'conscience_storage_service.dart';

// ============================================================================
// SHARED CONTEXT — coordination board for Benjamin & Harper
// ============================================================================

/// A shared, thread-safe context that Benjamin and Harper agents use to
/// coordinate their work. Written to the conscience thought board and also
/// held in-memory for fast reads.
class SharedAgentContext {
  final Map<String, dynamic> _data = {};
  final _controller = StreamController<Map<String, dynamic>>.broadcast();

  /// Read a value from the shared context.
  dynamic get(String key) => _data[key];

  /// Write a value to the shared context and notify listeners.
  void set(String key, dynamic value) {
    _data[key] = value;
    _controller.add({key: value});
  }

  /// Remove a key from the shared context.
  void remove(String key) {
    _data.remove(key);
    _controller.add({key: null});
  }

  /// Snapshot of the entire context.
  Map<String, dynamic> snapshot() => Map.unmodifiable(_data);

  /// Stream of context changes.
  Stream<Map<String, dynamic>> get changes => _controller.stream;

  /// Dispose the underlying stream controller.
  void dispose() => _controller.close();
}

// ============================================================================
// SPAWNED INSTANCE MODEL
// ============================================================================

/// Represents a single spawned agent instance tracked in the conscience DB.
class SpawnedAgentInstance {
  final String instanceId;
  final String agentType; // 'benjamin' or 'harper'
  final String agentId; // OpenClaw agent ID
  final DateTime spawnedAt;
  final String status; // 'spawning', 'running', 'stopped', 'error'
  final String? errorMessage;
  final String? correlationId; // Links Benjamin ↔ Harper spawn pairs

  SpawnedAgentInstance({
    required this.instanceId,
    required this.agentType,
    required this.agentId,
    required this.spawnedAt,
    required this.status,
    this.errorMessage,
    this.correlationId,
  });

  Map<String, dynamic> toJson() => {
        'instance_id': instanceId,
        'agent_type': agentType,
        'agent_id': agentId,
        'spawned_at': spawnedAt.toIso8601String(),
        'status': status,
        'error_message': errorMessage,
        'correlation_id': correlationId,
      };

  factory SpawnedAgentInstance.fromJson(Map<String, dynamic> json) =>
      SpawnedAgentInstance(
        instanceId: json['instance_id'] as String,
        agentType: json['agent_type'] as String,
        agentId: json['agent_id'] as String,
        spawnedAt: DateTime.parse(json['spawned_at'] as String),
        status: json['status'] as String,
        errorMessage: json['error_message'] as String?,
        correlationId: json['correlation_id'] as String?,
      );

  SpawnedAgentInstance copyWith({
    String? status,
    String? errorMessage,
  }) =>
      SpawnedAgentInstance(
        instanceId: instanceId,
        agentType: agentType,
        agentId: agentId,
        spawnedAt: spawnedAt,
        status: status ?? this.status,
        errorMessage: errorMessage ?? this.errorMessage,
        correlationId: correlationId,
      );
}

// ============================================================================
// SPAWN RESULT
// ============================================================================

/// Result of a parallel spawn operation.
class SpawnResult {
  final bool success;
  final String? message;
  final List<SpawnedAgentInstance> instances;
  final String? correlationId;

  SpawnResult({
    required this.success,
    this.message,
    required this.instances,
    this.correlationId,
  });
}

// ============================================================================
// MULTI-AGENT SPAWNER SERVICE
// ============================================================================

/// Service for spawning Benjamin and Harper agents on demand with parallel
/// execution. Tracks spawned instances in the conscience database and provides
/// lifecycle management (start, stop, monitor) via the OpenClaw Gateway.
///
/// ## Usage
/// ```dart
/// final spawner = MultiAgentSpawnerService(
///   lifecycleService: agentLifecycleService,
///   storageService: conscienceStorageService,
/// );
///
/// // Spawn both agents in parallel
/// final result = await spawner.spawnBenjaminAndHarper();
///
/// // Monitor spawned instances
/// final instances = spawner.activeInstances;
///
/// // Stop all spawned agents
/// await spawner.stopAll();
/// ```
class MultiAgentSpawnerService extends ChangeNotifier {
  final AgentLifecycleService _lifecycleService;
  final ConscienceStorageService _storageService;
  final Uuid _uuid = const Uuid();

  /// Shared context for Benjamin & Harper coordination.
  final SharedAgentContext sharedContext = SharedAgentContext();

  /// In-memory tracking of spawned instances.
  final Map<String, SpawnedAgentInstance> _instances = {};

  /// Timer for periodic health monitoring.
  Timer? _monitorTimer;

  /// Whether a spawn operation is in progress.
  bool _isSpawning = false;

  /// Last error encountered.
  String? _lastError;

  MultiAgentSpawnerService({
    required AgentLifecycleService lifecycleService,
    required ConscienceStorageService storageService,
  })  : _lifecycleService = lifecycleService,
        _storageService = storageService;

  // --------------------------------------------------------------------------
  // PUBLIC ACCESSORS
  // --------------------------------------------------------------------------

  /// All currently tracked spawned instances.
  List<SpawnedAgentInstance> get activeInstances =>
      _instances.values.where((i) => i.status != 'stopped').toList();

  /// All instances (including stopped).
  List<SpawnedAgentInstance> get allInstances => _instances.values.toList();

  /// Whether a spawn is in progress.
  bool get isSpawning => _isSpawning;

  /// Last error message.
  String? get lastError => _lastError;

  /// Get a specific instance by its instance ID.
  SpawnedAgentInstance? getInstance(String instanceId) =>
      _instances[instanceId];

  /// Get instances by agent type.
  List<SpawnedAgentInstance> getInstancesByType(String agentType) =>
      _instances.values.where((i) => i.agentType == agentType).toList();

  // --------------------------------------------------------------------------
  // SPAWN — Benjamin & Harper in parallel
  // --------------------------------------------------------------------------

  /// Spawn Benjamin and Harper agents in parallel.
  ///
  /// Returns a [SpawnResult] with both instances. If one fails, the other
  /// is still started and the result reports the partial failure.
  Future<SpawnResult> spawnBenjaminAndHarper({
    String? taskDescription,
    Map<String, dynamic>? sharedInitialContext,
  }) async {
    if (_isSpawning) {
      return SpawnResult(
        success: false,
        message: 'A spawn operation is already in progress',
        instances: [],
      );
    }

    _isSpawning = true;
    _lastError = null;
    notifyListeners();

    final correlationId = _uuid.v4();

    // Seed shared context if provided
    if (sharedInitialContext != null) {
      for (final entry in sharedInitialContext.entries) {
        sharedContext.set(entry.key, entry.value);
      }
    }
    sharedContext.set('correlation_id', correlationId);
    sharedContext.set('task_description', taskDescription ?? '');
    sharedContext.set('spawned_at', DateTime.now().toIso8601String());

    try {
      debugPrint(
          '[MultiAgentSpawner] Spawning Benjamin & Harper (correlation: $correlationId)');

      // Spawn both agents in parallel
      final results = await Future.wait([
        _spawnSingleAgent('benjamin', correlationId),
        _spawnSingleAgent('harper', correlationId),
      ]);

      final instances = <SpawnedAgentInstance>[];
      final errors = <String>[];

      for (final result in results) {
        if (result != null) {
          instances.add(result);
          _instances[result.instanceId] = result;
        } else {
          errors.add('Failed to spawn ${result == results.first ? 'Benjamin' : 'Harper'}');
        }
      }

      // Post a coordination thought to the conscience board
      await _postSpawnThought(instances, correlationId, taskDescription);

      final success = instances.isNotEmpty;
      if (!success) {
        _lastError = errors.join('; ');
      }

      debugPrint(
          '[MultiAgentSpawner] Spawn complete: ${instances.length} instance(s)');

      return SpawnResult(
        success: success,
        message: success
            ? 'Spawned ${instances.map((i) => i.agentType).join(' & ')}'
            : _lastError,
        instances: instances,
        correlationId: correlationId,
      );
    } catch (e) {
      _lastError = 'Spawn failed: $e';
      debugPrint('[MultiAgentSpawner] ✗ $_lastError');
      return SpawnResult(
        success: false,
        message: _lastError,
        instances: [],
        correlationId: correlationId,
      );
    } finally {
      _isSpawning = false;
      notifyListeners();
    }
  }

  /// Spawn a single agent via the lifecycle service.
  Future<SpawnedAgentInstance?> _spawnSingleAgent(
    String agentType,
    String correlationId,
  ) async {
    final instanceId = _uuid.v4();
    final now = DateTime.now();

    // Register the spawning instance in memory
    final instance = SpawnedAgentInstance(
      instanceId: instanceId,
      agentType: agentType,
      agentId: '', // Will be filled after start
      spawnedAt: now,
      status: 'spawning',
      correlationId: correlationId,
    );
    _instances[instanceId] = instance;

    // Post a "spawning" thought to the conscience board
    await _storageService.writeThought(
      agent: agentType,
      thoughtType: 'intention',
      content: 'Agent $agentType spawning (correlation: $correlationId)',
      channel: 'coordination',
      metadata: {
        'instance_id': instanceId,
        'correlation_id': correlationId,
        'status': 'spawning',
      },
    );

    try {
      // Start the agent via OpenClaw Gateway
      final result = await _lifecycleService.startAgent(agentType);

      if (!result.success) {
        final error = result.message ?? 'Unknown error starting $agentType';
        _instances[instanceId] = instance.copyWith(
          status: 'error',
          errorMessage: error,
        );

        await _storageService.writeThought(
          agent: agentType,
          thoughtType: 'observation',
          content: 'Agent $agentType failed to spawn: $error',
          channel: 'coordination',
          metadata: {
            'instance_id': instanceId,
            'correlation_id': correlationId,
            'status': 'error',
            'error': error,
          },
        );

        notifyListeners();
        return null;
      }

      // Extract the agent ID from the result
      final agentId = result.data is Map
          ? (result.data as Map)['agentId'] as String? ?? agentType
          : agentType;

      final spawned = SpawnedAgentInstance(
        instanceId: instanceId,
        agentType: agentType,
        agentId: agentId,
        spawnedAt: now,
        status: 'running',
        correlationId: correlationId,
      );
      _instances[instanceId] = spawned;

      // Post a "running" thought to the conscience board
      await _storageService.writeThought(
        agent: agentType,
        thoughtType: 'observation',
        content: 'Agent $agentType is now running (agentId: $agentId)',
        channel: 'coordination',
        metadata: {
          'instance_id': instanceId,
          'agent_id': agentId,
          'correlation_id': correlationId,
          'status': 'running',
        },
      );

      notifyListeners();
      return spawned;
    } catch (e) {
      final error = 'Exception spawning $agentType: $e';
      _instances[instanceId] = instance.copyWith(
        status: 'error',
        errorMessage: error,
      );

      await _storageService.writeThought(
        agent: agentType,
        thoughtType: 'observation',
        content: error,
        channel: 'coordination',
        metadata: {
          'instance_id': instanceId,
          'correlation_id': correlationId,
          'status': 'error',
          'error': '$e',
        },
      );

      notifyListeners();
      return null;
    }
  }

  /// Post a summary thought after a parallel spawn completes.
  Future<void> _postSpawnThought(
    List<SpawnedAgentInstance> instances,
    String correlationId,
    String? taskDescription,
  ) async {
    final summary = StringBuffer();
    summary.writeln('## Multi-Agent Spawn Summary');
    summary.writeln('- Correlation ID: $correlationId');
    if (taskDescription != null && taskDescription.isNotEmpty) {
      summary.writeln('- Task: $taskDescription');
    }
    summary.writeln('- Instances:');
    for (final instance in instances) {
      summary.writeln(
          '  - ${instance.agentType}: ${instance.instanceId} [${instance.status}]');
    }

    await _storageService.writeThought(
      agent: 'hermes',
      thoughtType: 'summary',
      content: summary.toString(),
      channel: 'coordination',
      metadata: {
        'correlation_id': correlationId,
        'instance_count': instances.length,
        'instance_ids': instances.map((i) => i.instanceId).toList(),
        'agent_types': instances.map((i) => i.agentType).toList(),
      },
    );
  }

  // --------------------------------------------------------------------------
  // LIFECYCLE MANAGEMENT
  // --------------------------------------------------------------------------

  /// Stop a specific spawned instance.
  Future<bool> stopInstance(String instanceId) async {
    final instance = _instances[instanceId];
    if (instance == null) {
      _lastError = 'Instance not found: $instanceId';
      return false;
    }

    try {
      debugPrint('[MultiAgentSpawner] Stopping instance: $instanceId');

      final result = await _lifecycleService.stopAgent(instance.agentId);

      if (result.success) {
        _instances[instanceId] = instance.copyWith(status: 'stopped');

        await _storageService.writeThought(
          agent: instance.agentType,
          thoughtType: 'observation',
          content:
              'Agent ${instance.agentType} stopped (instance: $instanceId)',
          channel: 'coordination',
          metadata: {
            'instance_id': instanceId,
            'agent_id': instance.agentId,
            'status': 'stopped',
          },
        );

        notifyListeners();
        return true;
      } else {
        _lastError = result.message;
        _instances[instanceId] = instance.copyWith(
          status: 'error',
          errorMessage: result.message,
        );
        notifyListeners();
        return false;
      }
    } catch (e) {
      _lastError = 'Error stopping instance $instanceId: $e';
      _instances[instanceId] = instance.copyWith(
        status: 'error',
        errorMessage: _lastError,
      );
      notifyListeners();
      return false;
    }
  }

  /// Stop all active spawned instances.
  Future<Map<String, bool>> stopAll() async {
    final results = <String, bool>{};
    final active = activeInstances.toList();

    if (active.isEmpty) {
      debugPrint('[MultiAgentSpawner] No active instances to stop');
      return results;
    }

    debugPrint(
        '[MultiAgentSpawner] Stopping all ${active.length} instance(s)...');

    // Stop all in parallel
    final futures = active.map((instance) async {
      final success = await stopInstance(instance.instanceId);
      results[instance.instanceId] = success;
    });

    await Future.wait(futures);

    // Post summary
    final stoppedCount = results.values.where((v) => v).length;
    await _storageService.writeThought(
      agent: 'hermes',
      thoughtType: 'summary',
      content: 'Stopped $stoppedCount/${active.length} agent instances',
      channel: 'coordination',
      metadata: {
        'total': active.length,
        'stopped': stoppedCount,
        'results': results,
      },
    );

    return results;
  }

  /// Get the current status of a spawned instance from the gateway.
  Future<SpawnedAgentInstance?> getInstanceStatus(String instanceId) async {
    final instance = _instances[instanceId];
    if (instance == null) return null;

    try {
      final status = await _lifecycleService.getAgentStatus(instance.agentId);
      if (status != null) {
        final updated = instance.copyWith(
          status: status.state == AgentLifecycleState.running
              ? 'running'
              : status.state == AgentLifecycleState.error
                  ? 'error'
                  : status.state == AgentLifecycleState.stopping
                      ? 'stopping'
                      : status.state == AgentLifecycleState.idle
                          ? 'stopped'
                          : instance.status,
          errorMessage: status.errorMessage,
        );
        _instances[instanceId] = updated;
        notifyListeners();
        return updated;
      }
      return instance;
    } catch (e) {
      debugPrint(
          '[MultiAgentSpawner] Error getting status for $instanceId: $e');
      return instance;
    }
  }

  // --------------------------------------------------------------------------
  // HEALTH MONITORING
  // --------------------------------------------------------------------------

  /// Start periodic health monitoring of all active instances.
  ///
  /// Checks every [interval] (default 30 seconds) and posts status thoughts
  /// to the conscience board when state changes are detected.
  void startMonitoring({Duration interval = const Duration(seconds: 30)}) {
    _monitorTimer?.cancel();
    _monitorTimer = Timer.periodic(interval, (_) => _monitorHealth());
    debugPrint(
        '[MultiAgentSpawner] Health monitoring started (interval: ${interval.inSeconds}s)');
  }

  /// Stop periodic health monitoring.
  void stopMonitoring() {
    _monitorTimer?.cancel();
    _monitorTimer = null;
    debugPrint('[MultiAgentSpawner] Health monitoring stopped');
  }

  /// Check health of all active instances.
  Future<void> _monitorHealth() async {
    final active = activeInstances.toList();
    if (active.isEmpty) return;

    for (final instance in active) {
      try {
        final status = await _lifecycleService.getAgentStatus(instance.agentId);
        if (status != null) {
          final newStatus = status.state == AgentLifecycleState.running
              ? 'running'
              : status.state == AgentLifecycleState.error
                  ? 'error'
                  : status.state == AgentLifecycleState.stopping
                      ? 'stopping'
                      : status.state == AgentLifecycleState.idle
                          ? 'stopped'
                          : instance.status;

          if (newStatus != instance.status) {
            _instances[instance.instanceId] = instance.copyWith(
              status: newStatus,
              errorMessage: status.errorMessage,
            );

            await _storageService.writeThought(
              agent: instance.agentType,
              thoughtType: 'observation',
              content:
                  'Agent ${instance.agentType} status changed: ${instance.status} → $newStatus',
              channel: 'coordination',
              metadata: {
                'instance_id': instance.instanceId,
                'agent_id': instance.agentId,
                'previous_status': instance.status,
                'new_status': newStatus,
              },
            );

            notifyListeners();
          }
        }
      } catch (e) {
        debugPrint(
            '[MultiAgentSpawner] Health check failed for ${instance.instanceId}: $e');
      }
    }
  }

  // --------------------------------------------------------------------------
  // SHARED CONTEXT HELPERS
  // --------------------------------------------------------------------------

  /// Post a thought from a spawned agent to the shared context board.
  Future<void> postAgentThought({
    required String agentType,
    required String thoughtType,
    required String content,
    String channel = 'coordination',
    Map<String, dynamic>? metadata,
  }) async {
    await _storageService.writeThought(
      agent: agentType,
      thoughtType: thoughtType,
      content: content,
      channel: channel,
      metadata: metadata,
    );
  }

  /// Get recent thoughts from the shared context board.
  Future<List<Map<String, dynamic>>> getRecentThoughts({
    String? agent,
    String? channel,
    int limit = 20,
  }) async {
    return await _storageService.getThoughts(
      agent: agent,
      channel: channel,
      limit: limit,
    );
  }

  // --------------------------------------------------------------------------
  // DISPOSAL
  // --------------------------------------------------------------------------

  @override
  void dispose() {
    stopMonitoring();
    sharedContext.dispose();
    _instances.clear();
    super.dispose();
  }
}
