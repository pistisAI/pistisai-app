/// Screen displaying the local skills registry and skills per category.
library;

import 'package:flutter/material.dart';
import '../../services/skill_service.dart';
import '../../di/locator.dart' as di;
import '../../l10n/app_localizations.dart';
import '../../widgets/common/empty_state.dart';
import '../../widgets/common/error_state.dart';
import '../../widgets/common/loading_skeleton.dart';
import '../../widgets/common/refreshable_screen.dart';

/// Skill model for displaying in the registry.
///
/// Only fields read from the skill's folder on disk are kept. Enable/disable,
/// use counts and response times are not tracked by Hermes skills yet, so the
/// screen does not show them (#858).
class Skill {
  final String id;
  final String name;
  final String description;
  final String category;
  final int fileCount;
  final DateTime? lastModified;

  const Skill({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    this.fileCount = 1,
    this.lastModified,
  });
}

/// Screen displaying the skills registry and skills per category.
class SkillsScreen extends StatefulWidget {
  const SkillsScreen({super.key});

  @override
  State<SkillsScreen> createState() => _SkillsScreenState();
}

class _SkillsScreenState extends State<SkillsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  String? _errorMessage;

  List<Skill> _skills = [];
  Map<String, int> _skillsPerCategory = {};

  SkillService? get _skillService {
    try {
      return di.serviceLocator<SkillService>();
    } catch (_) {
      return null;
    }
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final service = _skillService;
      if (service != null) {
        final skillInfos = await service.getSkills();
        _skills = skillInfos
            .map((s) => Skill(
                  id: s.name,
                  name: s.name,
                  description: s.description,
                  category: s.category,
                  fileCount: s.fileCount,
                  lastModified: s.lastModified,
                ))
            .toList();

        final perCategory = <String, int>{};
        for (final s in skillInfos) {
          perCategory[s.category] = (perCategory[s.category] ?? 0) + 1;
        }
        _skillsPerCategory = perCategory;
      } else {
        _skills = [];
        _skillsPerCategory = {};
      }

      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = '$e';
          _skills = [];
          _skillsPerCategory = {};
        });
      }
    }
  }

  Future<void> _onRefresh() async {
    await _loadData();
  }

  Future<void> _showRegisterSkillDialog() async {
    final l10n = AppLocalizations.of(context);
    final service = _skillService;
    if (service == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.skillsServiceUnavailable),
        ),
      );
      return;
    }

    final created = await showDialog<_SkillDraft>(
      context: context,
      builder: (context) => _RegisterSkillDialog(
        skillsDirectory: service.skillsDirectory,
      ),
    );
    if (created == null) return;

    try {
      final skill = await service.registerSkill(
        name: created.name,
        description: created.description,
        category: created.category,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.skillsRegistered(skill.name))),
      );
      await _loadData();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.skillsRegisterFailed('$e'))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return RefreshableScreen(
      onRefresh: _onRefresh,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.skillsTitle),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _onRefresh,
              tooltip: l10n.commonRefresh,
            ),
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: _showRegisterSkillDialog,
              tooltip: l10n.skillsRegisterTitle,
            ),
          ],
          bottom: TabBar(
            controller: _tabController,
            tabs: [
              Tab(
                  text: l10n.skillsTabRegistry,
                  icon: const Icon(Icons.extension_outlined)),
              Tab(
                  text: l10n.skillsTabCategories,
                  icon: const Icon(Icons.category_outlined)),
            ],
          ),
        ),
        body: _isLoading
            ? const LoadingSkeleton(itemCount: 3, height: 200)
            : _errorMessage != null
                ? ErrorState(message: _errorMessage!, onRetry: _onRefresh)
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _buildRegistryTab(l10n),
                      _buildCategoriesTab(l10n),
                    ],
                  ),
      ),
    );
  }

  Widget _buildRegistryTab(AppLocalizations l10n) {
    if (_skills.isEmpty) {
      return EmptyState(
        icon: Icons.extension,
        title: l10n.skillsEmptyTitle,
        message: l10n.skillsEmptyMessage,
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _skills.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final skill = _skills[index];
        return _buildSkillCard(skill);
      },
    );
  }

  Widget _buildSkillCard(Skill skill) {
    final theme = Theme.of(context);

    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _getCategoryIcon(skill.category),
                  size: 32,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              skill.name,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Chip(
                            label: Text(skill.category),
                            visualDensity: VisualDensity.compact,
                            backgroundColor:
                                theme.colorScheme.surfaceContainerHighest,
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        skill.description,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _buildStat(
                    Icons.description_outlined,
                    AppLocalizations.of(context)
                        .skillsFileCount(skill.fileCount)),
                if (skill.lastModified != null) ...[
                  const SizedBox(width: 16),
                  _buildStat(
                      Icons.access_time,
                      AppLocalizations.of(context)
                          .skillsModified(_formatModified(skill.lastModified!))),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStat(IconData icon, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon,
            size: 14,
            color:
                Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5)),
        const SizedBox(width: 4),
        Text(
          value,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontFamily: 'monospace',
                fontWeight: FontWeight.w500,
              ),
        ),
      ],
    );
  }

  Widget _buildCategoriesTab(AppLocalizations l10n) {
    if (_skillsPerCategory.isEmpty) {
      return EmptyState(
        icon: Icons.category_outlined,
        title: l10n.skillsEmptyTitle,
        message: l10n.skillsEmptyMessage,
      );
    }
    final maxCount = _skillsPerCategory.values.reduce((a, b) => a > b ? a : b);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.skillsByCategory,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 24),
          ..._skillsPerCategory.entries.map((entry) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(entry.key,
                          style: Theme.of(context).textTheme.bodyLarge),
                      Text(l10n.skillsCountInCategory(entry.value),
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(
                                color: Theme.of(context).colorScheme.primary,
                                fontWeight: FontWeight.bold,
                              )),
                    ],
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: entry.value / maxCount,
                    backgroundColor:
                        Theme.of(context).colorScheme.surfaceContainerHighest,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'development':
        return Icons.code;
      case 'text processing':
        return Icons.text_snippet;
      case 'utilities':
        return Icons.build;
      case 'data science':
        return Icons.analytics;
      case 'media':
        return Icons.image;
      default:
        return Icons.extension;
    }
  }

  String _formatModified(DateTime dt) {
    final l10n = AppLocalizations.of(context);
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inMinutes < 60) {
      return l10n.timeMinutesAgo(diff.inMinutes);
    } else if (diff.inHours < 24) {
      return l10n.timeHoursAgo(diff.inHours);
    } else if (diff.inDays < 7) {
      return l10n.timeDaysAgo(diff.inDays);
    } else {
      return '${dt.month}/${dt.day}';
    }
  }
}

class _SkillDraft {
  const _SkillDraft({
    required this.name,
    required this.description,
    required this.category,
  });

  final String name;
  final String description;
  final String category;
}

class _RegisterSkillDialog extends StatefulWidget {
  const _RegisterSkillDialog({required this.skillsDirectory});

  final String skillsDirectory;

  @override
  State<_RegisterSkillDialog> createState() => _RegisterSkillDialogState();
}

class _RegisterSkillDialogState extends State<_RegisterSkillDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _categoryController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _descriptionController = TextEditingController();
    _categoryController = TextEditingController(text: 'custom');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _categoryController.dispose();
    super.dispose();
  }

  void _submit() {
    final l10n = AppLocalizations.of(context);
    final name = _nameController.text.trim();
    final description = _descriptionController.text.trim();
    if (name.isEmpty || description.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.skillsNameDescriptionRequired)),
      );
      return;
    }

    Navigator.pop(
      context,
      _SkillDraft(
        name: name,
        description: description,
        category: _categoryController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.skillsRegisterTitle),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.skillsCreatesUnder(widget.skillsDirectory),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: l10n.commonName,
                hintText: 'summarize-selection',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _categoryController,
              decoration: InputDecoration(
                labelText: l10n.commonCategory,
                hintText: 'custom',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descriptionController,
              decoration: InputDecoration(
                labelText: l10n.commonDescription,
              ),
              maxLines: 3,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.commonCancel),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(l10n.agentsRegister),
        ),
      ],
    );
  }
}
