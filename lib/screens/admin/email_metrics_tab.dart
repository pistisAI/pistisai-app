import 'package:flutter/material.dart';
import '../../di/locator.dart' as di;
import '../../services/admin_center_service.dart';
import '../../models/admin_role_model.dart';
import 'dart:async';
import '../../config/theme.dart';

/// Email Metrics Dashboard Tab for the Admin Center
/// Displays email delivery metrics, charts, and real-time updates
class EmailMetricsTab extends StatefulWidget {
  const EmailMetricsTab({super.key});

  @override
  State<EmailMetricsTab> createState() => _EmailMetricsTabState();
}

class _EmailMetricsTabState extends State<EmailMetricsTab> {
  // State
  bool _isLoading = false;
  String? _error;
  Map<String, dynamic>? _metrics;
  List<HourlyMetric> _hourlyData = [];
  List<FailureReason> _failureReasons = [];
  Timer? _refreshTimer;

  // Filters
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void initState() {
    super.initState();
    _initializeDateRange();
    _loadMetrics();
    if (!const bool.fromEnvironment('FLUTTER_TEST')) {
      // Refresh metrics every 30 seconds for real-time updates
      _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
        if (mounted) {
          _loadMetrics();
        }
      });
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  /// Initialize date range (last 7 days)
  void _initializeDateRange() {
    _endDate = DateTime.now();
    _startDate = _endDate!.subtract(const Duration(days: 7));
  }

  /// Load email metrics from backend
  Future<void> _loadMetrics() async {
    final adminService = di.serviceLocator.get<AdminCenterService>();

    // Check permission
    if (!adminService.hasPermission(AdminPermission.viewConfiguration)) {
      setState(() {
        _error = 'You do not have permission to view email metrics';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Call the metrics endpoint
      final response = await adminService.getDio().get(
        '/admin/email/metrics',
        queryParameters: {
          'startDate': _startDate?.toIso8601String(),
          'endDate': _endDate?.toIso8601String(),
        },
      );

      final data = response.data['data'] ?? {};

      // Parse metrics
      final metrics = {
        'sent_count': data['sent_count'] ?? 0,
        'failed_count': data['failed_count'] ?? 0,
        'bounced_count': data['bounced_count'] ?? 0,
        'pending_count': data['pending_count'] ?? 0,
        'total_count': data['total_count'] ?? 0,
        'avg_delivery_time_seconds': data['avg_delivery_time_seconds'] ?? 0,
        'p50_delivery_time_seconds': data['p50_delivery_time_seconds'] ?? 0,
        'p95_delivery_time_seconds': data['p95_delivery_time_seconds'] ?? 0,
        'p99_delivery_time_seconds': data['p99_delivery_time_seconds'] ?? 0,
      };

      // Parse hourly data
      final hourlyData = (data['hourly_breakdown'] as List?)
              ?.map(
                (item) => HourlyMetric(
                  hour: DateTime.parse(item['hour']),
                  sentCount: item['sent_count'] ?? 0,
                  failedCount: item['failed_count'] ?? 0,
                  bouncedCount: item['bounced_count'] ?? 0,
                  totalCount: item['total_count'] ?? 0,
                ),
              )
              .toList() ??
          [];

      // Parse failure reasons
      final failureReasons = (data['failure_reasons'] as List?)
              ?.map(
                (item) => FailureReason(
                  reason: item['error_reason'] ?? 'Unknown',
                  count: item['count'] ?? 0,
                ),
              )
              .toList() ??
          [];

      setState(() {
        _metrics = metrics;
        _hourlyData = hourlyData;
        _failureReasons = failureReasons;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load email metrics: $e';
        _isLoading = false;
      });
    }
  }

  /// Handle date range change
  Future<void> _showDateRangePicker() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _startDate != null && _endDate != null
          ? DateTimeRange(start: _startDate!, end: _endDate!)
          : null,
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
      await _loadMetrics();
    }
  }

  /// Format duration in seconds to readable string
  String _formatDuration(double? seconds) {
    if (seconds == null || seconds.isNaN) return 'N/A';
    if (seconds < 1) return '${(seconds * 1000).toStringAsFixed(0)}ms';
    if (seconds < 60) return '${seconds.toStringAsFixed(1)}s';
    final minutes = seconds / 60;
    return '${minutes.toStringAsFixed(1)}m';
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Email Metrics Dashboard',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Monitor email delivery performance and metrics',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyLarge?.copyWith(color: AppTheme.colorsOf(context).textColorLight),
                ),
              ],
            ),
          ),

          // Date range filter and refresh
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Row(
              children: [
                OutlinedButton.icon(
                  icon: const Icon(Icons.date_range),
                  label: Text(
                    _startDate != null && _endDate != null
                        ? '${_formatDate(_startDate!)} - ${_formatDate(_endDate!)}'
                        : 'Select Date Range',
                  ),
                  onPressed: _showDateRangePicker,
                ),
                const SizedBox(width: 16),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _isLoading ? null : _loadMetrics,
                  tooltip: 'Refresh metrics',
                ),
                const Spacer(),
                Text(
                  'Auto-refresh: Every 30s',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: AppTheme.colorsOf(context).textColorLight.withOpacity(0.7)),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Error message
          if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.colorsOf(context).danger.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.colorsOf(context).danger.withOpacity(0.2)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: AppTheme.colorsOf(context).danger),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _error!,
                        style: TextStyle(color: AppTheme.colorsOf(context).danger),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => setState(() => _error = null),
                      color: AppTheme.colorsOf(context).danger,
                    ),
                  ],
                ),
              ),
            ),

          // Loading indicator
          if (_isLoading && _metrics == null)
            const Padding(
              padding: EdgeInsets.all(32.0),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_metrics != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Key metrics cards
                  _buildMetricsGrid(),
                  const SizedBox(height: 32),

                  // Delivery time distribution
                  _buildDeliveryTimeCard(),
                  const SizedBox(height: 32),

                  // Hourly breakdown chart
                  _buildHourlyBreakdownCard(),
                  const SizedBox(height: 32),

                  // Failure reasons
                  if (_failureReasons.isNotEmpty) ...[
                    _buildFailureReasonsCard(),
                    const SizedBox(height: 32),
                  ],
                ],
              ),
            ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  /// Build metrics grid with key statistics
  Widget _buildMetricsGrid() {
    // shrinkWrap: true is intentional — this is a small fixed grid (4 metric cards)
    // embedded in a non-scrollable Column. No lazy loading needed.
    return GridView.count(
      crossAxisCount: 4,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      children: [
        _buildMetricCard(
          title: 'Total Sent',
          value: (_metrics!['sent_count'] ?? 0).toString(),
          icon: Icons.check_circle,
          color: AppTheme.colorsOf(context).success,
        ),
        _buildMetricCard(
          title: 'Failed',
          value: (_metrics!['failed_count'] ?? 0).toString(),
          icon: Icons.error,
          color: AppTheme.colorsOf(context).danger,
        ),
        _buildMetricCard(
          title: 'Bounced',
          value: (_metrics!['bounced_count'] ?? 0).toString(),
          icon: Icons.mail_outline,
          color: AppTheme.colorsOf(context).warning,
        ),
        _buildMetricCard(
          title: 'Pending',
          value: (_metrics!['pending_count'] ?? 0).toString(),
          icon: Icons.schedule,
          color: AppTheme.colorsOf(context).info,
        ),
      ],
    );
  }

  /// Build individual metric card
  Widget _buildMetricCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 32, color: color),
            const SizedBox(height: 12),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppTheme.colorsOf(context).textColorLight.withOpacity(0.7)),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  /// Build delivery time statistics card
  Widget _buildDeliveryTimeCard() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Delivery Time Distribution',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildDeliveryTimeMetric(context,
                  label: 'Average',
                  value: _formatDuration(
                    _metrics!['avg_delivery_time_seconds'] as double?,
                  ),
                ),
                _buildDeliveryTimeMetric(context,
                  label: 'P50 (Median)',
                  value: _formatDuration(
                    _metrics!['p50_delivery_time_seconds'] as double?,
                  ),
                ),
                _buildDeliveryTimeMetric(context,
                  label: 'P95',
                  value: _formatDuration(
                    _metrics!['p95_delivery_time_seconds'] as double?,
                  ),
                ),
                _buildDeliveryTimeMetric(context,
                  label: 'P99',
                  value: _formatDuration(
                    _metrics!['p99_delivery_time_seconds'] as double?,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Build delivery time metric display
  Widget _buildDeliveryTimeMetric(BuildContext context, {
    required String label,
    required String value,
  }) {
    return Column(
      children: [
        Text(
          value,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppTheme.colorsOf(context).info,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: AppTheme.colorsOf(context).textColorLight.withOpacity(0.7)),
        ),
      ],
    );
  }

  /// Build hourly breakdown card
  Widget _buildHourlyBreakdownCard() {
    if (_hourlyData.isEmpty) {
      return Card(
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Hourly Breakdown',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 24),
              Center(
                child: Text(
                  'No data available for the selected date range',
                  style: TextStyle(color: AppTheme.colorsOf(context).textColorLight.withOpacity(0.7)),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Hourly Breakdown',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('Hour')),
                  DataColumn(label: Text('Sent')),
                  DataColumn(label: Text('Failed')),
                  DataColumn(label: Text('Bounced')),
                  DataColumn(label: Text('Total')),
                ],
                rows: _hourlyData
                    .map(
                      (metric) => DataRow(
                        cells: [
                          DataCell(Text(_formatDateTime(metric.hour))),
                          DataCell(
                            Text(
                              metric.sentCount.toString(),
                              style: TextStyle(color: AppTheme.colorsOf(context).success),
                            ),
                          ),
                          DataCell(
                            Text(
                              metric.failedCount.toString(),
                              style: TextStyle(color: AppTheme.colorsOf(context).danger),
                            ),
                          ),
                          DataCell(
                            Text(
                              metric.bouncedCount.toString(),
                              style: TextStyle(color: AppTheme.colorsOf(context).warning),
                            ),
                          ),
                          DataCell(Text(metric.totalCount.toString())),
                        ],
                      ),
                    )
                    .toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build failure reasons card
  Widget _buildFailureReasonsCard() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Top Failure Reasons',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            // shrinkWrap: true is intentional — failure reasons is a bounded list
            // (top N reasons, typically < 20 items) embedded in a Card > Column.
            // Not suitable for lazy loading since the list is always small.
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _failureReasons.length,
              separatorBuilder: (context, index) => const Divider(),
              itemBuilder: (context, index) {
                final reason = _failureReasons[index];
                final totalFailed = _metrics!['failed_count'] ?? 0;
                final percentage = totalFailed > 0
                    ? (reason.count / totalFailed * 100).toStringAsFixed(1)
                    : '0.0';

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              reason.reason,
                              style: Theme.of(context).textTheme.bodyMedium,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${reason.count} failures ($percentage%)',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(color: AppTheme.colorsOf(context).textColorLight.withOpacity(0.7)),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.colorsOf(context).danger.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          reason.count.toString(),
                          style: TextStyle(
                            color: AppTheme.colorsOf(context).danger,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Format date to readable string
  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  /// Format datetime to readable string
  String _formatDateTime(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} ${date.hour.toString().padLeft(2, '0')}:00';
  }
}

/// Hourly metric data model
class HourlyMetric {
  final DateTime hour;
  final int sentCount;
  final int failedCount;
  final int bouncedCount;
  final int totalCount;

  HourlyMetric({
    required this.hour,
    required this.sentCount,
    required this.failedCount,
    required this.bouncedCount,
    required this.totalCount,
  });
}

/// Failure reason data model
class FailureReason {
  final String reason;
  final int count;

  FailureReason({required this.reason, required this.count});
}
