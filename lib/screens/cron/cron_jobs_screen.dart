/// Screen for managing scheduled cron jobs.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import '../../services/cron_service.dart';
import '../../di/locator.dart' as di;
import '../../widgets/common/empty_state.dart';
import '../../widgets/common/error_state.dart';
import '../../widgets/common/loading_skeleton.dart';
import '../../widgets/common/refreshable_screen.dart';
import '../../widgets/common/status_badge.dart';
import '../../widgets/navigation/popout_button.dart';
import '../../models/cron_job.dart';

/// Screen displaying and managing scheduled cron jobs.
class CronJobsScreen extends StatefulWidget {
  const CronJobsScreen({super.key});

  @override
  State<CronJobsScreen> createState() => _CronJobsScreenState();
}

class _CronJobsScreenState extends State<CronJobsScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  List<CronJob> _jobs = [];

  CronService? get _cronService {
    try { return di.serviceLocator<CronService>(); } catch (_) { return null; }
  }

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final service = _cronService;
      if (service != null) {
        _jobs = await service.listJobs();
      } else {
        _jobs = [];
      }
      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      if (mounted) {
        setState(() { _isLoading = false; _jobs = []; });
      }
    }
  }

  Future<void> _onRefresh() async => _loadData();

  Future<void> _toggleJob(CronJob job) async {
    final service = _cronService;
    if (service == null) return;
    final isActive = job.status == CronJobStatus.active;
    await service.toggleJob(job.id, isActive);
    await _loadData();
  }

  Future<void> _runJob(CronJob job) async {
    final service = _cronService;
    if (service == null) return;
    await service.runJobNow(job.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Triggered: ${job.name}')),
    );
  }

  /// Edit job schedule
  Future<void> _editJob(CronJob job) async {
    await _showJobDialog(job: job);
  }

  /// Delete job
  Future<void> _deleteJob(CronJob job) async {
    final service = _cronService;
    if (service == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        final theme = Theme.of(context);
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: theme.colorScheme.error),
              const SizedBox(width: 8),
              const Text('Delete Scheduled Job'),
            ],
          ),
          content: Text('Are you sure you want to delete "${job.name}"? This action cannot be undone.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.error,
                foregroundColor: theme.colorScheme.onError,
              ),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      final success = await service.removeJob(job.id);
      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Job deleted successfully')),
          );
          unawaited(_loadData());
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to delete job')),
          );
        }
      }
    }
  }

  /// Show dialog to add or edit a cron job
  Future<void> _showJobDialog({CronJob? job}) async {
    final service = _cronService;
    if (service == null) return;

    final isEditing = job != null;
    final formKey = GlobalKey<FormState>();

    final nameController = TextEditingController(text: job?.name ?? '');
    final scheduleController = TextEditingController(text: job?.schedule ?? '');
    final promptController = TextEditingController();
    final scriptController = TextEditingController(text: job?.command ?? '');
    final workdirController = TextEditingController(text: job?.workdir ?? '');
    bool noAgent = job?.noAgent ?? false;
    bool isSaving = false;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final theme = Theme.of(context);
            return AlertDialog(
              title: Row(
                children: [
                  Icon(
                    isEditing ? Icons.edit_calendar_outlined : Icons.add_alarm_outlined,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(isEditing ? 'Edit Scheduled Job' : 'Create Scheduled Job'),
                ],
              ),
              content: SizedBox(
                width: 500,
                child: Form(
                  key: formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Name Field
                        TextFormField(
                          controller: nameController,
                          decoration: const InputDecoration(
                            labelText: 'Job Name',
                            hintText: 'e.g. Daily Briefing',
                            prefixIcon: Icon(Icons.label_outline),
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Please enter a job name';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // Schedule Field
                        TextFormField(
                          controller: scheduleController,
                          decoration: const InputDecoration(
                            labelText: 'Schedule Expression / Interval',
                            hintText: 'e.g. 30m, every 2h, or 0 9 * * *',
                            prefixIcon: Icon(Icons.schedule_outlined),
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Please enter a schedule';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 8),

                        // Presets row
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            _buildPresetChip('30m', scheduleController, setDialogState),
                            _buildPresetChip('every 2h', scheduleController, setDialogState),
                            _buildPresetChip('0 9 * * *', scheduleController, setDialogState),
                            _buildPresetChip('0 0 * * *', scheduleController, setDialogState),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Execution Mode Selector
                        Text(
                          'Execution Mode',
                          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        SegmentedButton<bool>(
                          segments: const [
                            ButtonSegment(
                              value: false,
                              label: Text('LLM Agent'),
                              icon: Icon(Icons.psychology_outlined),
                            ),
                            ButtonSegment(
                              value: true,
                              label: Text('Script Only (Watchdog)'),
                              icon: Icon(Icons.terminal_outlined),
                            ),
                          ],
                          selected: {noAgent},
                          onSelectionChanged: (value) {
                            setDialogState(() {
                              noAgent = value.first;
                            });
                          },
                        ),
                        const SizedBox(height: 16),

                        // Prompt Field (Only if noAgent is false)
                        if (!noAgent) ...[
                          TextFormField(
                            controller: promptController,
                            maxLines: 3,
                            decoration: const InputDecoration(
                              labelText: 'Agent Instruction / Prompt',
                              hintText: 'Describe the task the agent should perform periodically...',
                              prefixIcon: Icon(Icons.chat_bubble_outline),
                              border: OutlineInputBorder(),
                            ),
                            validator: (value) {
                              if (!noAgent && (value == null || value.trim().isEmpty) && scriptController.text.trim().isEmpty) {
                                return 'Please enter instructions or attach a script';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                        ],

                        // Script Field
                        TextFormField(
                          controller: scriptController,
                          decoration: InputDecoration(
                            labelText: noAgent ? 'Script File (Required)' : 'Script File (Optional)',
                            hintText: 'e.g. backup-vault.sh',
                            prefixIcon: const Icon(Icons.code_outlined),
                            border: const OutlineInputBorder(),
                            helperText: 'Scripts must live under ~/.hermes/scripts/',
                          ),
                          validator: (value) {
                            if (noAgent && (value == null || value.trim().isEmpty)) {
                              return 'Script file is required in Watchdog mode';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // Working Directory
                        TextFormField(
                          controller: workdirController,
                          decoration: const InputDecoration(
                            labelText: 'Workspace Directory (Optional)',
                            hintText: 'Absolute path to project directory',
                            prefixIcon: Icon(Icons.folder_open_outlined),
                            border: OutlineInputBorder(),
                            helperText: 'Injects project-level AGENTS.md/CLAUDE.md context',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSaving ? null : () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: isSaving
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) return;

                          setDialogState(() {
                            isSaving = true;
                          });

                          bool success;
                          if (isEditing) {
                            success = await service.editJob(
                              jobId: job.id,
                              schedule: scheduleController.text.trim(),
                              name: nameController.text.trim(),
                              prompt: noAgent ? '' : promptController.text.trim(),
                              script: scriptController.text.trim(),
                              noAgent: noAgent,
                              workdir: workdirController.text.trim(),
                            );
                          } else {
                            success = await service.createJob(
                              schedule: scheduleController.text.trim(),
                              name: nameController.text.trim(),
                              prompt: noAgent ? null : promptController.text.trim(),
                              script: scriptController.text.trim(),
                              noAgent: noAgent,
                              workdir: workdirController.text.trim(),
                            );
                          }

                          if (context.mounted) {
                            Navigator.of(context).pop();
                            if (success) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(isEditing
                                      ? 'Job updated successfully'
                                      : 'Job created successfully'),
                                  backgroundColor: theme.colorScheme.primary,
                                ),
                              );
                              unawaited(_loadData());
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Failed to save scheduled job'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          }
                        },
                  child: isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(isEditing ? 'Save' : 'Create'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildPresetChip(String val, TextEditingController controller, StateSetter setDialogState) {
    return ActionChip(
      label: Text(val),
      onPressed: () {
        setDialogState(() {
          controller.text = val;
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return RefreshableScreen(
      onRefresh: _onRefresh,
      errorMessage: _errorMessage,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Cron Jobs'),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _isLoading ? null : _onRefresh,
              tooltip: 'Refresh',
            ),
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: _isLoading ? null : _showJobDialog,
              tooltip: 'Add Job',
            ),
            const PopOutButton(sectionName: 'cron', branchIndex: 6),
          ],
        ),
        body: _isLoading
            ? const LoadingSkeleton(itemCount: 3, height: 120)
            : _errorMessage != null
                ? ErrorState(message: _errorMessage!, onRetry: _onRefresh)
                : _jobs.isEmpty
                    ? const EmptyState(
                        icon: Icons.schedule_outlined,
                        title: 'No Cron Jobs',
                        message:
                            'Create scheduled tasks to automate maintenance',
                      )
                    : _buildJobsList(),
      ),
    );
  }

  Widget _buildJobsList() {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _jobs.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final job = _jobs[index];
        return _buildJobCard(job);
      },
    );
  }

  Widget _buildJobCard(CronJob job) {
    final theme = Theme.of(context);
    final statusColor = job.getStatusColor(context);

    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with name and status
            Row(
              children: [
                Icon(
                  job.statusIcon,
                  size: 20,
                  color: statusColor,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        job.name,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        job.scheduleDescription,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ),
                StatusBadge(
                  status: job.status == CronJobStatus.active
                      ? StatusType.active
                      : job.status == CronJobStatus.inactive
                          ? StatusType.stopped
                          : job.status == CronJobStatus.failed
                              ? StatusType.error
                              : StatusType.running,
                  label: job.statusText,
                  showIcon: false,
                ),
              ],
            ),
            const Divider(height: 24),
            // Schedule and timing info
            _buildInfoRow(
              Icons.schedule_outlined,
              'Schedule',
              job.schedule,
            ),
            const SizedBox(height: 8),
            if (job.nextRun != null)
              _buildInfoRow(
                Icons.access_time,
                'Next run',
                _formatDateTime(job.nextRun!),
              ),
            if (job.lastRun != null) ...[
              const SizedBox(height: 8),
              _buildInfoRow(
                Icons.history,
                'Last run',
                _formatDateTime(job.lastRun!),
                status: job.lastRunStatusText,
              ),
            ],
            if (job.lastRunOutput != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  children: [
                    Icon(
                      job.lastRunSuccess
                          ? Icons.check_circle_outline
                          : Icons.error_outline,
                      size: 16,
                      color: job.lastRunSuccess
                          ? theme.colorScheme.primary
                          : theme.colorScheme.error,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        job.lastRunOutput!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontFamily: 'monospace',
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (job.noAgent) ...[
              const SizedBox(height: 8),
              _buildInfoRow(
                Icons.terminal_outlined,
                'Mode',
                'Watchdog (No Agent)',
              ),
            ],
            if (job.workdir != null && job.workdir!.isNotEmpty) ...[
              const SizedBox(height: 8),
              _buildInfoRow(
                Icons.folder_open_outlined,
                'Workdir',
                job.workdir!,
              ),
            ],
            const SizedBox(height: 16),
            // Actions
            Wrap(
              spacing: 8,
              children: [
                TextButton.icon(
                  onPressed: () => _runJob(job),
                  icon: const Icon(Icons.play_arrow, size: 18),
                  label: const Text('Run Now'),
                ),
                TextButton.icon(
                  onPressed: () => _editJob(job),
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('Edit'),
                ),
                TextButton.icon(
                  onPressed: () => _toggleJob(job),
                  icon: Icon(
                    job.status == CronJobStatus.active
                        ? Icons.pause
                        : Icons.play_arrow,
                    size: 18,
                  ),
                  label: Text(
                    job.status == CronJobStatus.active ? 'Disable' : 'Enable',
                  ),
                ),
                TextButton.icon(
                  onPressed: () => _deleteJob(job),
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: const Text('Delete'),
                  style: TextButton.styleFrom(
                    foregroundColor: theme.colorScheme.error,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value,
      {String? status}) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon,
            size: 16,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: theme.textTheme.bodySmall?.copyWith(
              fontFamily: 'monospace',
            ),
          ),
        ),
        if (status != null)
          Text(
            status,
            style: theme.textTheme.bodySmall?.copyWith(
              color: status == 'Success'
                  ? theme.colorScheme.primary
                  : theme.colorScheme.error,
              fontWeight: FontWeight.w500,
            ),
          ),
      ],
    );
  }

  String _formatDateTime(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}
