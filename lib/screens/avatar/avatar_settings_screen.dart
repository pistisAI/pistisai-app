import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../brand/brand.dart';
import '../../services/avatar/avatar_state_service.dart';
import '../../services/settings_preference_service.dart';
import '../../models/avatar/personality_models.dart';
import '../../features/avatar/avatar_widget.dart';
import '../../di/locator.dart' as di;
import '../../l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';
import 'achievements_screen.dart';

/// Avatar Settings Screen
///
/// Allows users to customize their avatar's personality, name,
/// visual appearance, and manage evolution stages.
class AvatarSettingsScreen extends StatefulWidget {
  const AvatarSettingsScreen({super.key});

  @override
  State<AvatarSettingsScreen> createState() => _AvatarSettingsScreenState();
}

class _AvatarSettingsScreenState extends State<AvatarSettingsScreen> {
  late AvatarStateService _avatarStateService;
  late SettingsPreferenceService _settingsService;
  bool _isInitializing = true;
  bool _isLoading = false;
  String? _errorMessage;
  String? _successMessage;

  // Form state
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController =
      TextEditingController(text: Brand.current.productName);
  late double _formality;
  late double _humor;
  late double _enthusiasm;
  late double _empathy;

  // Appearance state
  String _colorTheme = 'personality';
  String _animationStyle = 'bounce';
  String _avatarType = 'emoji';
  String _avatarSize = 'medium';
  bool _glowEnabled = true;

  // Preview state
  AgentState _previewState = AgentState.idle;

  // Evolution state
  String _selectedEvolutionStage = 'curious_explorer';
  final TextEditingController _evolutionReasonController =
      TextEditingController();
  bool _isRequestingEvolution = false;
  Map<String, dynamic>? _evolutionRequirements;

  /// Size multipliers for avatar
  static const Map<String, double> _avatarSizeMultipliers = {
    'small': 0.8,
    'medium': 1.0,
    'large': 1.3,
  };

  AppLocalizations get _l10n => AppLocalizations.of(context);

  /// Error raised while initializing, formatted in build so the message
  /// follows the current locale.
  Object? _initError;

  @override
  void initState() {
    super.initState();
    _initializeService();
  }

  /// Initialize avatar state service
  Future<void> _initializeService() async {
    try {
      _avatarStateService = di.serviceLocator.get<AvatarStateService>();
      _settingsService = di.serviceLocator.get<SettingsPreferenceService>();

      // Listen to service changes
      _avatarStateService.addListener(_onAvatarStateChanged);

      // Load initial profile
      await _avatarStateService.loadProfile();

      // Load persisted appearance settings
      await _loadAppearanceSettings();

      // Initialize form state from current profile
      _initializeFormState();

      // Load evolution requirements
      await _loadEvolutionRequirements();

      setState(() {
        _isInitializing = false;
      });
    } catch (e) {
      setState(() {
        _isInitializing = false;
        _initError = e;
      });
      debugPrint('Error initializing avatar state service: $e');
    }
  }

  /// Load appearance settings from SettingsPreferenceService
  Future<void> _loadAppearanceSettings() async {
    try {
      _colorTheme = await _settingsService.getAvatarColorTheme();
      _animationStyle = await _settingsService.getAvatarAnimationStyle();
      _avatarType = await _settingsService.getAvatarType();
      _avatarSize = await _settingsService.getAvatarSize();
      _glowEnabled = await _settingsService.isAvatarGlowEnabled();
    } catch (e) {
      debugPrint('Error loading appearance settings: $e');
    }
  }

  /// Initialize form fields from current profile
  void _initializeFormState() {
    final profile = _avatarStateService.currentProfile;
    if (profile != null) {
      _nameController.text = profile.agentName;
      _formality = profile.traits.formality;
      _humor = profile.traits.humor;
      _enthusiasm = profile.traits.enthusiasm;
      _empathy = profile.traits.empathy;
      _selectedEvolutionStage = profile.evolutionStage;
    } else {
      // Default values
      _nameController.text = Brand.current.productName;
      _formality = PersonalityTraits.defaultTraits.formality;
      _humor = PersonalityTraits.defaultTraits.humor;
      _enthusiasm = PersonalityTraits.defaultTraits.enthusiasm;
      _empathy = PersonalityTraits.defaultTraits.empathy;
    }
  }

  /// Load evolution requirements
  Future<void> _loadEvolutionRequirements() async {
    try {
      final requirements = await _avatarStateService.getEvolutionRequirements();
      setState(() {
        _evolutionRequirements = requirements;
      });
    } catch (e) {
      debugPrint('Error loading evolution requirements: $e');
    }
  }

  /// Handle avatar state changes
  void _onAvatarStateChanged() {
    if (mounted) {
      final profile = _avatarStateService.currentProfile;
      if (profile != null) {
        setState(() {
          _nameController.text = profile.agentName;
          _formality = profile.traits.formality;
          _humor = profile.traits.humor;
          _enthusiasm = profile.traits.enthusiasm;
          _empathy = profile.traits.empathy;
          _selectedEvolutionStage = profile.evolutionStage;
        });
      }

      if (_avatarStateService.error != null) {
        setState(() {
          _errorMessage = _avatarStateService.error;
        });
      }
    }
  }

  static const _validEvolutionStages = {
    'curious_explorer',
    'knowledge_seeker',
    'wise_companion',
    'enlightened_guide',
  };

  bool _isValidStage(String stage) => _validEvolutionStages.contains(stage);

  /// Build personality traits from current slider values
  PersonalityTraits _buildTraits() => PersonalityTraits(
        formality: _formality,
        humor: _humor,
        enthusiasm: _enthusiasm,
        empathy: _empathy,
      );

  /// Get avatar size in pixels
  double _getAvatarSize() {
    final baseSize = 150.0;
    final multiplier = _avatarSizeMultipliers[_avatarSize] ?? 1.0;
    return baseSize * multiplier;
  }

  /// Save avatar settings
  Future<void> _saveSettings() async {
    final l10n = _l10n;
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      // Update agent name if changed
      if (_avatarStateService.agentName != _nameController.text) {
        await _avatarStateService.updateAgentName(_nameController.text);
      }

      // Update personality traits
      final traits = _buildTraits();
      await _avatarStateService.updateTraits(traits);

      // Persist personality traits to SettingsPreferenceService
      await _settingsService.setAvatarFormality(_formality);
      await _settingsService.setAvatarHumor(_humor);
      await _settingsService.setAvatarEnthusiasm(_enthusiasm);
      await _settingsService.setAvatarEmpathy(_empathy);

      // Persist appearance settings
      await _settingsService.setAvatarColorTheme(_colorTheme);
      await _settingsService.setAvatarAnimationStyle(_animationStyle);
      await _settingsService.setAvatarType(_avatarType);
      await _settingsService.setAvatarSize(_avatarSize);
      await _settingsService.setAvatarGlowEnabled(_glowEnabled);

      setState(() {
        _isLoading = false;
        _successMessage = l10n.avatarSaved;
        _errorMessage = null;
      });

      // Clear success message after 2 seconds
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          setState(() {
            _successMessage = null;
          });
        }
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = l10n.avatarSaveFailed('$e');
      });
    }
  }

  /// Request evolution to selected stage
  Future<void> _requestEvolution() async {
    final l10n = _l10n;
    final reason = _evolutionReasonController.text.trim();
    if (reason.isEmpty) {
      setState(() {
        _errorMessage = l10n.avatarEvolutionReasonMissing;
      });
      return;
    }

    setState(() {
      _isRequestingEvolution = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      final decision = await _avatarStateService.requestEvolution(
          _selectedEvolutionStage, reason);

      setState(() {
        _isRequestingEvolution = false;
      });

      if (decision.approved) {
        setState(() {
          _successMessage = l10n.avatarEvolutionApproved(
              _stageLabel(l10n, decision.newStage ?? _selectedEvolutionStage));
          _errorMessage = null;
        });

        // Reload requirements after evolution
        await _loadEvolutionRequirements();

        // Clear success message after 3 seconds
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) {
            setState(() {
              _successMessage = null;
            });
          }
        });
      } else {
        setState(() {
          _errorMessage = l10n.avatarEvolutionDenied(
              decision.reason ?? l10n.commonUnknownError);
        });
      }

      // Clear reason field
      _evolutionReasonController.clear();
    } catch (e) {
      setState(() {
        _isRequestingEvolution = false;
        _errorMessage = l10n.avatarEvolutionFailed('$e');
      });
    }
  }

  @override
  void dispose() {
    _avatarStateService.removeListener(_onAvatarStateChanged);
    _nameController.dispose();
    _evolutionReasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = _l10n;
    final errorMessage = _initError != null
        ? l10n.avatarInitFailed('$_initError')
        : _errorMessage;
    if (_isInitializing) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.avatarSettingsTitle)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return ChangeNotifierProvider<AvatarStateService>.value(
      value: _avatarStateService,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.avatarSettingsTitle),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.pop(),
            tooltip: l10n.commonBack,
          ),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Status messages
                if (errorMessage != null) _buildErrorMessage(errorMessage),
                if (_successMessage != null)
                  _buildSuccessMessage(_successMessage!),

                // Live avatar preview
                _buildLivePreview(),

                const SizedBox(height: 24),

                // Current status card
                _buildStatusCard(),

                const SizedBox(height: 24),

                // Agent name section
                _buildAgentNameSection(),

                const SizedBox(height: 24),

                // Personality traits section
                _buildPersonalityTraitsSection(),

                const SizedBox(height: 24),

                // Appearance options section
                _buildAppearanceSection(),

                const SizedBox(height: 24),

                // Visual customization section
                _buildVisualCustomizationSection(),

                const SizedBox(height: 24),

                // Achievements section
                _buildAchievementsSection(),

                const SizedBox(height: 24),

                // Evolution section
                _buildEvolutionSection(),

                const SizedBox(height: 32),

                // Save button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _saveSettings,
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(l10n.avatarSaveSettings),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Build live avatar preview section
  Widget _buildLivePreview() {
    final traits = _buildTraits();

    return Card(
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Text(
              _l10n.avatarLivePreview,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
            ),
            const SizedBox(height: 16),
            // Avatar preview
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .primaryContainer
                    .withValues(alpha: 0.3),
                shape: BoxShape.circle,
                border: Border.all(
                  color: Theme.of(context)
                      .colorScheme
                      .primary
                      .withValues(alpha: 0.3),
                  width: 2,
                ),
              ),
              padding: const EdgeInsets.all(24),
              child: AgentAvatar(
                state: _previewState,
                size: _getAvatarSize(),
                personality: traits,
              ),
            ),
            const SizedBox(height: 16),
            // State switcher for preview
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SegmentedButton<AgentState>(
                segments: [
                  ButtonSegment(
                    value: AgentState.idle,
                    label: Text(_l10n.avatarStateIdle),
                    icon: const Icon(Icons.pause_circle_outline),
                  ),
                  ButtonSegment(
                    value: AgentState.thinking,
                    label: Text(_l10n.avatarStateThinking),
                    icon: const Icon(Icons.psychology),
                  ),
                  ButtonSegment(
                    value: AgentState.working,
                    label: Text(_l10n.avatarStateWorking),
                    icon: const Icon(Icons.construction),
                  ),
                  ButtonSegment(
                    value: AgentState.happy,
                    label: Text(_l10n.avatarStateHappy),
                    icon: const Icon(Icons.sentiment_satisfied),
                  ),
                  ButtonSegment(
                    value: AgentState.error,
                    label: Text(_l10n.commonError),
                    icon: const Icon(Icons.error_outline),
                  ),
                ],
                selected: {_previewState},
                onSelectionChanged: (state) {
                  setState(() => _previewState = state.first);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build error message widget
  Widget _buildErrorMessage(String message) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Theme.of(context).colorScheme.error),
      ),
      child: Row(
        children: [
          Icon(
            Icons.error_outline,
            color: Theme.of(context).colorScheme.error,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                  color: Theme.of(context).colorScheme.onErrorContainer),
            ),
          ),
        ],
      ),
    );
  }

  /// Build success message widget
  Widget _buildSuccessMessage(String message) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Theme.of(context).colorScheme.primary),
      ),
      child: Row(
        children: [
          Icon(
            Icons.check_circle_outline,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                  color: Theme.of(context).colorScheme.onPrimaryContainer),
            ),
          ),
        ],
      ),
    );
  }

  /// Build current status card
  Widget _buildStatusCard() {
    return Consumer<AvatarStateService>(
      builder: (context, avatarState, child) {
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.smart_toy,
                      color: Theme.of(context).colorScheme.primary,
                      size: 32,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            avatarState.agentName,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _l10n.avatarStageValue(
                                _stageLabel(_l10n, avatarState.evolutionStage)),
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  color: Theme.of(context).colorScheme.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _buildStatusItem(
                        icon: Icons.chat_bubble_outline,
                        label: _l10n.avatarConversations,
                        value: avatarState.conversationCount.toString(),
                      ),
                    ),
                    Expanded(
                      child: _buildStatusItem(
                        icon: Icons.insights,
                        label: _l10n.avatarDepthScore,
                        value:
                            (avatarState.depthScore * 100).toStringAsFixed(0),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Build status item widget
  Widget _buildStatusItem({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Column(
      children: [
        Icon(icon,
            size: 20, color: Theme.of(context).colorScheme.onSurfaceVariant),
        const SizedBox(height: 4),
        Text(
          value,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  /// Build agent name section
  Widget _buildAgentNameSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _l10n.avatarAgentName,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _nameController,
              decoration: InputDecoration(
                hintText: _l10n.avatarAgentNameHint,
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.badge),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return _l10n.avatarAgentNameRequired;
                }
                if (value.trim().length < 2) {
                  return _l10n.avatarAgentNameTooShort;
                }
                if (value.trim().length > 50) {
                  return _l10n.avatarAgentNameTooLong;
                }
                return null;
              },
            ),
            const SizedBox(height: 8),
            Text(
              _l10n.avatarAgentNameHelp,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build personality traits section
  Widget _buildPersonalityTraitsSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _l10n.avatarPersonalityTraits,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              _l10n.avatarPersonalityHelp,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 16),
            _buildTraitSlider(
              label: _l10n.homeTraitFormality,
              value: _formality,
              onChanged: (value) => setState(() => _formality = value),
              icon: Icons.business_center,
              description: _l10n.avatarFormalityDescription,
            ),
            const SizedBox(height: 16),
            _buildTraitSlider(
              label: _l10n.homeTraitHumor,
              value: _humor,
              onChanged: (value) => setState(() => _humor = value),
              icon: Icons.sentiment_very_satisfied,
              description: _l10n.avatarHumorDescription,
            ),
            const SizedBox(height: 16),
            _buildTraitSlider(
              label: _l10n.homeTraitEnthusiasm,
              value: _enthusiasm,
              onChanged: (value) => setState(() => _enthusiasm = value),
              icon: Icons.emoji_emotions,
              description: _l10n.avatarEnthusiasmDescription,
            ),
            const SizedBox(height: 16),
            _buildTraitSlider(
              label: _l10n.homeTraitEmpathy,
              value: _empathy,
              onChanged: (value) => setState(() => _empathy = value),
              icon: Icons.favorite,
              description: _l10n.avatarEmpathyDescription,
            ),
          ],
        ),
      ),
    );
  }

  /// Build trait slider widget
  Widget _buildTraitSlider({
    required String label,
    required double value,
    required ValueChanged<double> onChanged,
    required IconData icon,
    required String description,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ),
            Text(
              (value * 100).toStringAsFixed(0),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: Theme.of(context).colorScheme.primary,
            inactiveTrackColor:
                Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
            thumbColor: Theme.of(context).colorScheme.primary,
          ),
          child: Slider(
            value: value,
            min: 0.0,
            max: 1.0,
            divisions: 100,
            label: (value * 100).toStringAsFixed(0),
            onChanged: onChanged,
          ),
        ),
        Text(
          description,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
      ],
    );
  }

  /// Build appearance options section
  Widget _buildAppearanceSection() {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.palette, color: colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  _l10n.avatarAppearance,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              _l10n.avatarAppearanceHelp,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 16),

            // Color theme selector
            Text(
              _l10n.avatarColorTheme,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _colorTheme,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                prefixIcon: Icon(Icons.color_lens),
              ),
              items: [
                DropdownMenuItem(
                  value: 'personality',
                  child: Text(_l10n.avatarColorPersonality),
                ),
                DropdownMenuItem(
                  value: 'ocean_blue',
                  child: Text(_l10n.avatarColorOceanBlue),
                ),
                DropdownMenuItem(
                  value: 'forest_green',
                  child: Text(_l10n.avatarColorForestGreen),
                ),
                DropdownMenuItem(
                  value: 'sunset_orange',
                  child: Text(_l10n.avatarColorSunsetOrange),
                ),
                DropdownMenuItem(
                  value: 'royal_purple',
                  child: Text(_l10n.avatarColorRoyalPurple),
                ),
                DropdownMenuItem(
                  value: 'monochrome',
                  child: Text(_l10n.avatarColorMonochrome),
                ),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() => _colorTheme = value);
                }
              },
            ),

            const SizedBox(height: 16),

            // Animation style selector
            Text(
              _l10n.avatarAnimationStyle,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _animationStyle,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                prefixIcon: Icon(Icons.animation),
              ),
              items: [
                DropdownMenuItem(
                  value: 'bounce',
                  child: Text(_l10n.avatarAnimationBounce),
                ),
                DropdownMenuItem(
                  value: 'pulse',
                  child: Text(_l10n.avatarAnimationPulse),
                ),
                DropdownMenuItem(
                  value: 'float',
                  child: Text(_l10n.avatarAnimationFloat),
                ),
                DropdownMenuItem(
                  value: 'shake',
                  child: Text(_l10n.avatarAnimationShake),
                ),
                DropdownMenuItem(
                  value: 'none',
                  child: Text(_l10n.avatarAnimationNone),
                ),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() => _animationStyle = value);
                }
              },
            ),

            const SizedBox(height: 16),

            // Avatar size selector
            Text(
              _l10n.avatarSize,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              segments: [
                ButtonSegment(
                  value: 'small',
                  label: Text(_l10n.avatarSizeSmall),
                  icon: Icon(Icons.circle, size: 16),
                ),
                ButtonSegment(
                  value: 'medium',
                  label: Text(_l10n.avatarSizeMedium),
                  icon: Icon(Icons.circle, size: 24),
                ),
                ButtonSegment(
                  value: 'large',
                  label: Text(_l10n.avatarSizeLarge),
                  icon: Icon(Icons.circle, size: 32),
                ),
              ],
              selected: {_avatarSize},
              onSelectionChanged: (size) {
                setState(() => _avatarSize = size.first);
              },
            ),

            const SizedBox(height: 16),

            // Glow effect toggle
            Row(
              children: [
                Icon(Icons.light_mode, color: colorScheme.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _l10n.avatarGlowEffect,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _l10n.avatarGlowSubtitle,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: _glowEnabled,
                  onChanged: (value) {
                    setState(() => _glowEnabled = value);
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Build visual customization section
  Widget _buildVisualCustomizationSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.brush,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  _l10n.avatarAdvancedTitle,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _l10n.avatarAdvancedHelp,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => context.pushNamed('avatar-customization'),
                icon: const Icon(Icons.brush),
                label: Text(_l10n.avatarOpenAdvanced),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build achievements section
  Widget _buildAchievementsSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.emoji_events,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  _l10n.avatarAchievements,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _l10n.avatarAchievementsHelp,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const AchievementsScreen(),
                  ),
                ),
                icon: const Icon(Icons.emoji_events),
                label: Text(_l10n.avatarViewAchievements),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build evolution section
  Widget _buildEvolutionSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.auto_awesome,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  _l10n.avatarEvolution,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _l10n.avatarEvolutionHelp,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 16),

            // Current stage
            Consumer<AvatarStateService>(
              builder: (context, avatarState, child) {
                return Row(
                  children: [
                    Text(_l10n.avatarCurrentStage),
                    const SizedBox(width: 8),
                    Chip(
                      label:
                          Text(_stageLabel(_l10n, avatarState.evolutionStage)),
                      backgroundColor:
                          Theme.of(context).colorScheme.primaryContainer,
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 16),

            // Evolution requirements
            if (_evolutionRequirements != null) _buildEvolutionRequirements(),

            const SizedBox(height: 16),

            // Evolution request form
            DropdownButtonFormField<String>(
              initialValue: _isValidStage(_selectedEvolutionStage)
                  ? _selectedEvolutionStage
                  : 'curious_explorer',
              decoration: InputDecoration(
                labelText: _l10n.avatarEvolveTo,
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.trending_up),
              ),
              items: [
                DropdownMenuItem(
                  value: 'curious_explorer',
                  child: Text(_l10n.avatarStageCuriousExplorerInitial),
                ),
                DropdownMenuItem(
                  value: 'knowledge_seeker',
                  child: Text(_l10n.avatarStageKnowledgeSeeker),
                ),
                DropdownMenuItem(
                  value: 'wise_companion',
                  child: Text(_l10n.avatarStageWiseCompanion),
                ),
                DropdownMenuItem(
                  value: 'enlightened_guide',
                  child: Text(_l10n.avatarStageEnlightenedGuide),
                ),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _selectedEvolutionStage = value;
                  });
                }
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _evolutionReasonController,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: _l10n.avatarEvolutionReason,
                hintText: _l10n.avatarEvolutionReasonHint,
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.edit_note),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return _l10n.avatarEvolutionReasonRequired;
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isRequestingEvolution ? null : _requestEvolution,
                icon: _isRequestingEvolution
                    ? const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.auto_awesome),
                label: Text(_isRequestingEvolution
                    ? _l10n.avatarRequesting
                    : _l10n.avatarRequestEvolution),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build evolution requirements display
  Widget _buildEvolutionRequirements() {
    final reqs = _evolutionRequirements!;
    final canEvolve = reqs['can_evolve'] as bool;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: canEvolve
            ? Theme.of(context)
                .colorScheme
                .primaryContainer
                .withValues(alpha: 0.3)
            : Theme.of(context)
                .colorScheme
                .errorContainer
                .withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: canEvolve
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.error,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                canEvolve ? Icons.check_circle : Icons.info_outline,
                color: canEvolve
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.error,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                canEvolve
                    ? _l10n.avatarReadyToEvolve
                    : _l10n.avatarEvolutionRequirements,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: canEvolve
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.error,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildRequirementProgress(
            label: _l10n.avatarDeepConversations,
            current: reqs['deep_conversations'] as int,
            required: reqs['required_deep_conversations'] as int,
          ),
          const SizedBox(height: 8),
          _buildRequirementProgress(
            label: _l10n.avatarAverageNovelty,
            current: ((reqs['average_novelty'] as double) * 100).toInt(),
            required: ((reqs['required_novelty'] as double) * 100).toInt(),
            isPercentage: true,
          ),
        ],
      ),
    );
  }

  /// Localized name of an evolution stage id; unknown ids are shown as is.
  static String _stageLabel(AppLocalizations l10n, String stage) {
    switch (stage) {
      case 'curious_explorer':
        return l10n.avatarStageCuriousExplorer;
      case 'knowledge_seeker':
        return l10n.avatarStageKnowledgeSeeker;
      case 'wise_companion':
        return l10n.avatarStageWiseCompanion;
      case 'enlightened_guide':
        return l10n.avatarStageEnlightenedGuide;
      default:
        return stage;
    }
  }

  /// Build requirement progress widget
  Widget _buildRequirementProgress({
    required String label,
    required int current,
    required int required,
    bool isPercentage = false,
  }) {
    final isMet = current >= required;
    final progress = (current / required).clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            Text(
              isPercentage
                  ? _l10n.avatarRequirementPercent(current, required)
                  : '$current / $required',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: isMet
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor:
                Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1),
            valueColor: AlwaysStoppedAnimation<Color>(
              isMet
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            minHeight: 6,
          ),
        ),
      ],
    );
  }
}
