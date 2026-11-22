import 'package:flutter/foundation.dart';
import 'package:pistisai/database/drift_local_brain.dart';
import 'package:pistisai/services/avatar/personality_engine.dart';
import 'package:pistisai/services/avatar/evolution_tracker.dart';
import 'package:pistisai/services/avatar/markdown_sync_service.dart';
import 'package:drift/drift.dart' show Value;
import 'package:pistisai/models/avatar/personality_models.dart';
import 'package:pistisai/models/conversation.dart' as models;
import 'package:pistisai/models/message.dart' as msg;

/// Centralized service for managing avatar state across the application.
///
/// Provides reactive state management via ChangeNotifier and integrates with
/// PersonalityEngine and EvolutionTracker for avatar evolution.
class AvatarStateService extends ChangeNotifier {
  final LocalBrain _database;
  final PersonalityEngine _personalityEngine;
  final EvolutionTracker _evolutionTracker;
  final MarkdownSyncService _markdownSyncService;

  ExtendedAvatarProfile? _currentProfile;
  bool _isLoading = false;
  String? _error;

  AvatarStateService({
    required LocalBrain database,
    required PersonalityEngine personalityEngine,
    required EvolutionTracker evolutionTracker,
    required MarkdownSyncService markdownSyncService,
  })  : _database = database,
        _personalityEngine = personalityEngine,
        _evolutionTracker = evolutionTracker,
        _markdownSyncService = markdownSyncService;

  // Getters
  ExtendedAvatarProfile? get currentProfile => _currentProfile;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Returns true if the avatar service is ready (profile loaded)
  bool get isReady => _currentProfile != null && !_isLoading;

  /// Returns the current evolution stage
  String get evolutionStage =>
      _currentProfile?.evolutionStage ?? 'curious_explorer';

  /// Returns the agent name
  String get agentName => _currentProfile?.agentName ?? 'Agent';

  /// Returns the current personality traits
  PersonalityTraits get traits =>
      _currentProfile?.traits ?? PersonalityTraits.defaultTraits;

  /// Returns the conversation count
  int get conversationCount => _currentProfile?.conversationCount ?? 0;

  /// Returns the depth score
  double get depthScore => _currentProfile?.depthScore ?? 0.0;

  /// Loads the current avatar profile from the database
  Future<void> loadProfile() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final profile = await _personalityEngine.getPersonality();
      _currentProfile = profile;
      _isLoading = false;
      notifyListeners();
      _publishPersonality(profile);
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      debugPrint('Error loading avatar profile: $e');
    }
  }

  /// Called when the name, traits or evolution stage change (and once at
  /// load), so the agent runtime can apply the personality. Must not throw.
  void Function(ExtendedAvatarProfile profile)? onPersonalityChanged;

  String? _publishedPersonality;

  void _publishPersonality(ExtendedAvatarProfile profile) {
    final listener = onPersonalityChanged;
    if (listener == null) return;
    final signature =
        '${profile.agentName}|${profile.traits.toMap()}|${profile.evolutionStage}';
    if (signature == _publishedPersonality) return;
    _publishedPersonality = signature;
    try {
      listener(profile);
    } catch (e) {
      debugPrint('Error publishing personality: $e');
    }
  }

  /// Publishes the current personality again, for example after the runtime
  /// connects.
  void republishPersonality() {
    _publishedPersonality = null;
    final profile = _currentProfile;
    if (profile != null) _publishPersonality(profile);
  }

  /// Updates the personality traits
  Future<void> updateTraits(PersonalityTraits traits) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _personalityEngine.updatePersonality(traits);
      await loadProfile(); // Reload to get updated state

      // Sync to markdown
      if (_currentProfile != null) {
        await _markdownSyncService.syncPersonality(_currentProfile!);
      }
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      debugPrint('Error updating traits: $e');
      rethrow;
    }
  }

  /// Updates the agent name
  Future<void> updateAgentName(String name) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _personalityEngine.updateAgentName(name);
      await loadProfile(); // Reload to get updated state

      // Sync to markdown
      if (_currentProfile != null) {
        await _markdownSyncService.syncPersonality(_currentProfile!);
      }
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      debugPrint('Error updating agent name: $e');
      rethrow;
    }
  }

  /// Requests an evolution to a new stage
  Future<EvolutionDecision> requestEvolution(
      String stage, String reason) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final decision =
          await _personalityEngine.validateEvolutionRequest(stage, reason);
      await loadProfile(); // Reload to get updated stage

      // Sync all data to markdown if evolution approved
      if (decision.approved && _currentProfile != null) {
        await _markdownSyncService.syncAll(_currentProfile!);
      }

      return decision;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      debugPrint('Error requesting evolution: $e');
      rethrow;
    }
  }

  /// A pause this long between two messages starts a new conversation. The
  /// app keeps one continuous chat channel, so "conversations" for the
  /// avatar's progress are sessions separated by inactivity.
  static const Duration sessionGap = Duration(minutes: 30);

  String? _lastRecordedMessageId;

  /// The trailing run of user/assistant messages with no pause of
  /// [sessionGap] or more between them.
  @visibleForTesting
  static List<msg.Message> currentSession(List<msg.Message> messages) {
    final chat = messages
        .where((m) => (m.isUser || m.isAssistant) && !m.isStreaming)
        .toList();
    if (chat.isEmpty) return chat;
    var start = chat.length - 1;
    while (start > 0 &&
        chat[start].timestamp.difference(chat[start - 1].timestamp) <
            sessionGap) {
      start--;
    }
    return chat.sublist(start);
  }

  /// Records progress after a completed exchange (a user message answered by
  /// the agent): refreshes the depth metrics of the current session, the
  /// conversation count and depth score, and unlocks earned achievements.
  ///
  /// Safe to call after every save: it does nothing until a new assistant
  /// reply is the last message.
  Future<void> recordExchange(models.Conversation conversation) async {
    try {
      final session = currentSession(conversation.messages);
      if (session.isEmpty) return;
      final last = session.last;
      if (!last.isAssistant || last.hasError || last.content.trim().isEmpty) {
        return;
      }
      if (!session.any((m) => m.isUser)) return;
      if (last.id == _lastRecordedMessageId) return;

      final complexity = await _evolutionTracker.calculateComplexity(session);
      final emotional =
          await _evolutionTracker.calculateEmotionalDepth(session);
      final novelty = await _evolutionTracker.calculateNovelty(session);
      final startedAt = session.first.timestamp.millisecondsSinceEpoch;

      await _database.upsertConversationDepthMetrics(
        ConversationDepthMetricsCompanion(
          id: Value('session_${conversation.id}_$startedAt'),
          conversationId: Value(conversation.id),
          complexityScore: Value(complexity),
          emotionalDepth: Value(emotional),
          noveltyScore: Value(novelty),
          timestamp: Value(last.timestamp.millisecondsSinceEpoch),
        ),
      );

      final all = await _database.getAllDepthMetrics();
      final count = all.length;
      final depth = all
              .map((m) =>
                  (m.complexityScore + m.emotionalDepth + m.noveltyScore) / 3)
              .reduce((a, b) => a + b) /
          count;
      final avgNovelty =
          all.map((m) => m.noveltyScore).reduce((a, b) => a + b) / count;
      await _database.updateAvatarProgress(
        conversationCount: count,
        depthScore: depth,
      );

      for (final id in earnedAchievements(
        conversationCount: count,
        averageNovelty: avgNovelty,
        evolutionStage: evolutionStage,
      )) {
        await _database.unlockAchievementById(id);
      }

      _lastRecordedMessageId = last.id;
      await loadProfile();
    } catch (e) {
      debugPrint('Error recording avatar progress: $e');
    }
  }

  /// Average novelty across tracked sessions (0 when there are none).
  Future<double> averageNovelty() async {
    final all = await _database.getAllDepthMetrics();
    if (all.isEmpty) return 0.0;
    return all.map((m) => m.noveltyScore).reduce((a, b) => a + b) / all.length;
  }

  /// Achievement ids earned for these values. Single source of truth for the
  /// achievements screen and for unlocking.
  static List<String> earnedAchievements({
    required int conversationCount,
    required double averageNovelty,
    required String evolutionStage,
  }) {
    const stages = [
      'curious_explorer',
      'knowledge_seeker',
      'wise_companion',
      'enlightened_guide',
    ];
    final stageIndex = stages.indexOf(evolutionStage);
    return [
      if (conversationCount >= 1) 'first_chat',
      if (conversationCount >= 5) 'deep_conversations_5',
      if (conversationCount >= 15) 'deep_conversations_15',
      if (conversationCount >= 30) 'deep_conversations_30',
      if (averageNovelty >= 0.6) 'high_novelty',
      if (stageIndex >= 1) 'knowledge_seeker',
      if (stageIndex >= 2) 'wise_companion',
      if (stageIndex >= 3) 'enlightened_guide',
    ];
  }

  /// Tracks depth metrics for a conversation
  Future<void> trackConversationDepth(
    String conversationId,
    double complexity,
    double emotional,
    double novelty,
  ) async {
    try {
      final randomSuffix = DateTime.now().microsecond.toRadixString(16);
      final id = 'depth_${DateTime.now().millisecondsSinceEpoch}_$randomSuffix';

      await _database.addConversationDepthMetrics(
        ConversationDepthMetricsCompanion.insert(
          id: id,
          conversationId: conversationId,
          complexityScore: complexity,
          emotionalDepth: emotional,
          noveltyScore: novelty,
          timestamp: DateTime.now().millisecondsSinceEpoch,
        ),
      );

      // Reload profile to check for evolution patterns
      await loadProfile();
    } catch (e) {
      debugPrint('Error tracking conversation depth: $e');
      _error = e.toString();
      notifyListeners();
    }
  }

  /// Checks if evolution is possible based on conversation patterns
  Future<bool> canEvolve() async {
    return await _evolutionTracker.hasEvolutionPatterns();
  }

  /// Returns the evolution requirements
  Future<Map<String, dynamic>> getEvolutionRequirements() async {
    final metrics = await _database.getDepthMetrics();

    final deepConversations =
        metrics.where((m) => m.complexityScore > 0.7).length;
    final avgNovelty = metrics.isEmpty
        ? 0.0
        : metrics.map((m) => m.noveltyScore).reduce((a, b) => a + b) /
            metrics.length;

    return {
      'deep_conversations': deepConversations,
      'required_deep_conversations': 5,
      'average_novelty': avgNovelty,
      'required_novelty': 0.5,
      'can_evolve': deepConversations >= 5 && avgNovelty > 0.5,
    };
  }

  /// Clears any error state
  void clearError() {
    _error = null;
    notifyListeners();
  }
}
