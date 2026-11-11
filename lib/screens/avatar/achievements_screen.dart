import 'package:flutter/material.dart';
import '../../services/avatar/avatar_state_service.dart';
import '../../di/locator.dart' as di;
import '../../database/drift_local_brain.dart';
import '../../config/theme.dart';
import '../../l10n/app_localizations.dart';

/// Screen for displaying avatar achievements
///
/// Shows unlocked and locked achievements with progress indicators.
class AchievementsScreen extends StatefulWidget {
  const AchievementsScreen({super.key});

  @override
  State<AchievementsScreen> createState() => _AchievementsScreenState();
}

class _AchievementsScreenState extends State<AchievementsScreen> {
  late AvatarStateService _avatarStateService;
  late LocalBrain _localBrain;
  bool _isLoading = true;

  /// Error raised while loading, formatted in build so the message follows
  /// the current locale.
  Object? _loadError;

  List<Achievement> _unlockedAchievements = [];
  Map<String, AchievementProgress> _progressMap = {};

  @override
  void initState() {
    super.initState();
    _initializeServices();
  }

  /// Initialize services
  Future<void> _initializeServices() async {
    try {
      _avatarStateService = di.serviceLocator.get<AvatarStateService>();
      _localBrain = di.serviceLocator.get<LocalBrain>();

      await _loadAchievements();
      await _loadProgress();

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _loadError = e;
        });
      }
    }
  }

  /// Load all achievements from database
  Future<void> _loadAchievements() async {
    try {
      _unlockedAchievements = await _localBrain.getUnlockedAchievements();
    } catch (e) {
      debugPrint('Error loading achievements: $e');
    }
  }

  /// Load achievement progress based on avatar state
  Future<void> _loadProgress() async {
    final avatarState = _avatarStateService.currentProfile;
    if (avatarState == null) {
      return;
    }

    final conversationCount = avatarState.conversationCount;
    final depthScore = avatarState.depthScore;
    final evolutionStage = avatarState.evolutionStage;

    setState(() {
      _progressMap = {
        'first_chat': AchievementProgress(
          completed: true,
          progress: 1.0,
          currentValue: 1,
          requiredValue: 1,
        ),
        'deep_conversations_5': AchievementProgress(
          completed: conversationCount >= 5,
          progress: (conversationCount / 5).clamp(0.0, 1.0),
          currentValue: conversationCount,
          requiredValue: 5,
        ),
        'deep_conversations_15': AchievementProgress(
          completed: conversationCount >= 15,
          progress: (conversationCount / 15).clamp(0.0, 1.0),
          currentValue: conversationCount,
          requiredValue: 15,
        ),
        'deep_conversations_30': AchievementProgress(
          completed: conversationCount >= 30,
          progress: (conversationCount / 30).clamp(0.0, 1.0),
          currentValue: conversationCount,
          requiredValue: 30,
        ),
        'high_novelty': AchievementProgress(
          completed: depthScore >= 0.6,
          progress: (depthScore / 0.6).clamp(0.0, 1.0),
          currentValue: (depthScore * 100).toInt(),
          requiredValue: 60,
          isPercentage: true,
        ),
        'knowledge_seeker': AchievementProgress(
          completed: evolutionStage == 'knowledge_seeker' ||
              evolutionStage == 'wise_companion' ||
              evolutionStage == 'enlightened_guide',
          progress: 0.0,
          currentValue: 0,
          requiredValue: 1,
        ),
        'wise_companion': AchievementProgress(
          completed: evolutionStage == 'wise_companion' ||
              evolutionStage == 'enlightened_guide',
          progress: 0.0,
          currentValue: 0,
          requiredValue: 1,
        ),
        'enlightened_guide': AchievementProgress(
          completed: evolutionStage == 'enlightened_guide',
          progress: 0.0,
          currentValue: 0,
          requiredValue: 1,
        ),
      };
    });
  }

  /// Get achievement metadata
  AchievementMetadata _getAchievementMetadata(
      BuildContext context, String achievementId) {
    final l10n = AppLocalizations.of(context);
    switch (achievementId) {
      case 'first_chat':
        return AchievementMetadata(
          title: l10n.achievementFirstChat,
          description: l10n.achievementFirstChatDescription,
          icon: Icons.chat_bubble_outline,
          color: AppTheme.colorsOf(context).info,
        );
      case 'deep_conversations_5':
        return AchievementMetadata(
          title: l10n.achievementGettingToKnow,
          description: l10n.achievementDeepConversationsDescription(5),
          icon: Icons.auto_awesome,
          color: AppTheme.colorsOf(context).success,
        );
      case 'deep_conversations_15':
        return AchievementMetadata(
          title: l10n.achievementDeepThinker,
          description: l10n.achievementDeepConversationsDescription(15),
          icon: Icons.psychology,
          color: AppTheme.colorsOf(context).accent,
        );
      case 'deep_conversations_30':
        return AchievementMetadata(
          title: l10n.achievementConversationalMaster,
          description: l10n.achievementDeepConversationsDescription(30),
          icon: Icons.school,
          color: AppTheme.colorsOf(context).warning,
        );
      case 'high_novelty':
        return AchievementMetadata(
          title: l10n.achievementNoveltySeeker,
          description: l10n.achievementNoveltySeekerDescription,
          icon: Icons.explore,
          color: AppTheme.colorsOf(context).info,
        );
      case 'knowledge_seeker':
        return AchievementMetadata(
          title: l10n.avatarStageKnowledgeSeeker,
          description: l10n
              .achievementEvolveDescription(l10n.avatarStageKnowledgeSeeker),
          icon: Icons.trending_up,
          color: AppTheme.colorsOf(context).primary,
        );
      case 'wise_companion':
        return AchievementMetadata(
          title: l10n.avatarStageWiseCompanion,
          description:
              l10n.achievementEvolveDescription(l10n.avatarStageWiseCompanion),
          icon: Icons.stars,
          color: AppTheme.colorsOf(context).warning,
        );
      case 'enlightened_guide':
        return AchievementMetadata(
          title: l10n.avatarStageEnlightenedGuide,
          description: l10n
              .achievementEvolveDescription(l10n.avatarStageEnlightenedGuide),
          icon: Icons.workspace_premium,
          color: AppTheme.colorsOf(context).danger,
        );
      default:
        return AchievementMetadata(
          title: achievementId,
          description: '',
          icon: Icons.emoji_events,
          color: AppTheme.colorsOf(context).textColorLight,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.achievementsTitle)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_loadError != null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.achievementsTitle)),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline,
                  size: 64, color: AppTheme.colorsOf(context).danger),
              const SizedBox(height: 16),
              Text(l10n.achievementsLoadFailed('$_loadError'),
                  textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _initializeServices,
                child: Text(l10n.commonRetry),
              ),
            ],
          ),
        ),
      );
    }

    final avatarState = _avatarStateService.currentProfile;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.achievementsTitle),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
          tooltip: l10n.commonBack,
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Stats card
            _buildStatsCard(),
            SizedBox(height: 24),

            // Unlocked achievements
            _buildSectionHeader(l10n.achievementsUnlockedSection,
                Icons.check_circle, AppTheme.colorsOf(context).success),
            const SizedBox(height: 12),
            if (_unlockedAchievements.isEmpty)
              _buildEmptyState(l10n.achievementsNoneUnlocked)
            else
              ..._unlockedAchievements.map((achievement) {
                final metadata =
                    _getAchievementMetadata(context, achievement.achievementId);
                return _buildAchievementCard(
                  achievement: achievement,
                  metadata: metadata,
                  isUnlocked: true,
                );
              }),

            SizedBox(height: 32),

            // Locked achievements
            _buildSectionHeader(l10n.achievementsLockedSection, Icons.lock,
                AppTheme.colorsOf(context).textColorLight),
            const SizedBox(height: 12),
            ..._progressMap.entries.where((entry) {
              final achievementId = entry.key;
              final isUnlocked = _unlockedAchievements
                  .any((a) => a.achievementId == achievementId);
              return !isUnlocked;
            }).map((entry) {
              final metadata = _getAchievementMetadata(context, entry.key);
              final progress = entry.value;
              return _buildAchievementCard(
                achievement: Achievement(
                  id: -1,
                  avatarId: avatarState?.agentName ?? 'default',
                  achievementId: entry.key,
                  achievementType: 'progress',
                  title: metadata.title,
                  description: metadata.description,
                  earnedAt: DateTime.now(),
                ),
                metadata: metadata,
                isUnlocked: false,
                progress: progress,
              );
            }),
          ],
        ),
      ),
    );
  }

  /// Build stats card
  Widget _buildStatsCard() {
    final l10n = AppLocalizations.of(context);
    final unlockedCount = _unlockedAchievements.length;
    final totalCount = _progressMap.length;
    final percentage =
        totalCount > 0 ? (unlockedCount / totalCount * 100).toInt() : 0;

    return Card(
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              children: [
                Icon(
                  Icons.emoji_events,
                  size: 32,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.achievementsProgress,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        l10n.achievementsUnlockedCount(
                            unlockedCount, totalCount),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppTheme.colorsOf(context).textColorLight,
                            ),
                      ),
                    ],
                  ),
                ),
                Text(
                  l10n.achievementsPercent(percentage),
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: unlockedCount / totalCount,
                backgroundColor: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.1),
                valueColor: AlwaysStoppedAnimation<Color>(
                  Theme.of(context).colorScheme.primary,
                ),
                minHeight: 8,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build section header
  Widget _buildSectionHeader(String title, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(width: 8),
        Text(
          title,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
        ),
      ],
    );
  }

  /// Build empty state
  Widget _buildEmptyState(String message) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Icon(
              Icons.emoji_events_outlined,
              size: 64,
              color: AppTheme.colorsOf(context).textColorLight,
            ),
            const SizedBox(height: 16),
            Text(
              message,
              style: TextStyle(
                fontSize: 16,
                color: AppTheme.colorsOf(context).textColorLight,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  /// Build achievement card
  Widget _buildAchievementCard({
    required Achievement achievement,
    required AchievementMetadata metadata,
    required bool isUnlocked,
    AchievementProgress? progress,
  }) {
    return Card(
      elevation: isUnlocked ? 3 : 1,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Icon
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: isUnlocked
                    ? metadata.color.withValues(alpha: 0.2)
                    : AppTheme.colorsOf(context).textColorLight,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isUnlocked
                      ? metadata.color
                      : AppTheme.colorsOf(context).textColorLight,
                  width: 2,
                ),
              ),
              child: Icon(
                metadata.icon,
                size: 32,
                color: isUnlocked
                    ? metadata.color
                    : AppTheme.colorsOf(context).textColorLight,
              ),
            ),
            const SizedBox(width: 16),
            // Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    metadata.title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    metadata.description,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.colorsOf(context).textColorLight,
                        ),
                  ),
                  if (!isUnlocked && progress != null) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: progress.progress,
                              backgroundColor: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: 0.1),
                              valueColor: AlwaysStoppedAnimation<Color>(
                                metadata.color.withValues(alpha: 0.8),
                              ),
                              minHeight: 6,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          progress.isPercentage
                              ? AppLocalizations.of(context)
                                  .achievementsPercent(progress.currentValue)
                              : '${progress.currentValue}/${progress.requiredValue}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: metadata.color,
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (isUnlocked && achievement.unlockedAt != null)
                    Text(
                      AppLocalizations.of(context).achievementsUnlockedWhen(
                          _formatDate(achievement.unlockedAt!)),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.primary,
                            fontStyle: FontStyle.italic,
                          ),
                    ),
                ],
              ),
            ),
            // Status icon
            if (isUnlocked)
              Icon(
                Icons.check_circle,
                color: AppTheme.colorsOf(context).success,
                size: 28,
              ),
          ],
        ),
      ),
    );
  }

  /// Format date
  String _formatDate(DateTime date) {
    final l10n = AppLocalizations.of(context);
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        return l10n.achievementsToday;
      }
      return l10n.timeHoursAgo(difference.inHours);
    } else if (difference.inDays == 1) {
      return l10n.achievementsYesterday;
    } else if (difference.inDays < 7) {
      return l10n.timeDaysAgo(difference.inDays);
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}

/// Achievement metadata
class AchievementMetadata {
  final String title;
  final String description;
  final IconData icon;
  final Color color;

  AchievementMetadata({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
  });
}

/// Achievement progress
class AchievementProgress {
  final bool completed;
  final double progress;
  final int currentValue;
  final int requiredValue;
  final bool isPercentage;

  AchievementProgress({
    required this.completed,
    required this.progress,
    required this.currentValue,
    required this.requiredValue,
    this.isPercentage = false,
  });
}
