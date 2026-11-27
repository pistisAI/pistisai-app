import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../brand/brand_copy.dart';
import '../../config/theme.dart';
import '../../l10n/app_localizations.dart';
import '../../components/modern_card.dart';
import '../../services/unified_connection_service.dart';
import '../../widgets/navigation/breadcrumb_bar.dart';
import '../../services/platform_adapter.dart';

/// System Tray Daemon Settings Screen
class DaemonSettingsScreen extends StatefulWidget {
  const DaemonSettingsScreen({super.key});

  @override
  State<DaemonSettingsScreen> createState() => _DaemonSettingsScreenState();
}

class _DaemonSettingsScreenState extends State<DaemonSettingsScreen> {
  // Defaults shown in disabled controls: no service stores or applies these
  // tray and connection settings yet.
  final bool _enableSystemTray = true;
  final bool _startMinimized = false;
  final bool _enableNotifications = true;
  final bool _autoStartDaemon = true;
  final String _selectedTheme = 'system';
  final int _connectionTimeout = 5;
  final int _healthCheckInterval = 30;

  // Real-time status tracking
  Map<String, dynamic>? _connectionStatus;
  bool _isLoadingStatus = false;
  DateTime? _lastStatusUpdate;

  @override
  void initState() {
    super.initState();
    debugPrint(' [DaemonSettingsScreen] Initializing screen');
    _loadConnectionStatus();
  }

  Future<void> _loadConnectionStatus() async {
    setState(() {
      _isLoadingStatus = true;
    });

    try {
      // Get connection status from unified connection service
      final connectionService = context.read<UnifiedConnectionService>();
      await connectionService.refreshConnectionStatus();

      setState(() {
        _connectionStatus = {
          'connected': connectionService.isConnected,
          'connection_type': connectionService.connectionType,
          'version': connectionService.version,
          'models': connectionService.models,
          'error': connectionService.error,
        };
        _lastStatusUpdate = DateTime.now();
      });
    } catch (e) {
      debugPrint('Failed to load connection status: $e');
      setState(() {
        _connectionStatus = {'connected': false, 'error': e.toString()};
        _lastStatusUpdate = DateTime.now();
      });
    } finally {
      setState(() {
        _isLoadingStatus = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    debugPrint(' [DaemonSettingsScreen] Building widget');
    final platformAdapter = Provider.of<PlatformAdapter>(context);
    final theme = Theme.of(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final l10n = AppLocalizations.of(context);

    // Responsive layout breakpoints
    final isMobile = screenWidth < 600;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(l10n.daemonSettingsTitle),
        backgroundColor: theme.appBarTheme.backgroundColor,
        foregroundColor: theme.appBarTheme.foregroundColor,
        elevation: 0,
        leading: platformAdapter.buildBackButton(
          context,
          onPressed: () => context.go('/settings/connection'),
        ),
      ),
      body: Column(
        children: [
          const AutoBreadcrumbBar(),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(isMobile ? 12.0 : AppTheme.spacingL),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Text(
                    l10n.daemonHeading,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          color: AppTheme.colorsOf(context).textColor,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  SizedBox(height: AppTheme.spacingS),
                  Text(
                    l10n.daemonDescription,
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(
                        color: AppTheme.colorsOf(context).textColorLight),
                  ),
                  SizedBox(height: AppTheme.spacingXL),

                  // Real-time Connection Status
                  _buildConnectionStatus(),
                  SizedBox(height: AppTheme.spacingL),

                  // Nothing below is saved or applied yet (AGENTS.md:
                  // "Controls tell the truth"), so the controls are shown
                  // disabled under a "not available yet" note.
                  _buildNotAvailableNote(),
                  SizedBox(height: AppTheme.spacingM),

                  // General Settings
                  _buildGeneralSettings(),
                  SizedBox(height: AppTheme.spacingL),

                  // Appearance Settings
                  _buildAppearanceSettings(),
                  SizedBox(height: AppTheme.spacingL),

                  // Connection Settings
                  _buildConnectionSettings(),

                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConnectionStatus() {
    final l10n = AppLocalizations.of(context);
    return ModernCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildSectionHeader(l10n.daemonRealtimeStatus, Icons.wifi),
              IconButton(
                onPressed: _isLoadingStatus ? null : _loadConnectionStatus,
                icon: _isLoadingStatus
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh),
              ),
            ],
          ),
          SizedBox(height: AppTheme.spacingM),
          if (_connectionStatus != null) ...[
            _buildStatusRow(
              l10n.connectionStatusTitle,
              _connectionStatus!['connected'] == true
                  ? l10n.commonConnected
                  : l10n.commonDisconnected,
              _connectionStatus!['connected'] == true
                  ? AppTheme.colorsOf(context).success
                  : AppTheme.colorsOf(context).danger,
            ),
            if (_connectionStatus!['connection_type'] != null)
              _buildStatusRow(
                l10n.daemonConnectionType,
                _connectionStatus!['connection_type'].toString().toUpperCase(),
                AppTheme.colorsOf(context).textColorLight,
              ),
            if (_connectionStatus!['version'] != null)
              _buildStatusRow(
                l10n.daemonVersion,
                _connectionStatus!['version'].toString(),
                AppTheme.colorsOf(context).textColorLight,
              ),
            if (_connectionStatus!['models'] != null)
              _buildStatusRow(
                l10n.daemonAvailableModels,
                l10n.daemonModelCount(
                  (_connectionStatus!['models'] as List).length,
                ),
                AppTheme.colorsOf(context).textColorLight,
              ),
            if (_connectionStatus!['error'] != null &&
                _connectionStatus!['error'].toString().isNotEmpty)
              _buildStatusRow(
                l10n.daemonError,
                _connectionStatus!['error'].toString(),
                AppTheme.colorsOf(context).danger,
              ),
            if (_lastStatusUpdate != null) ...[
              SizedBox(height: AppTheme.spacingS),
              Text(
                l10n.daemonLastUpdated(_formatDateTime(_lastStatusUpdate!)),
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(
                    color: AppTheme.colorsOf(context).textColorLight),
              ),
            ],
          ] else ...[
            Text(l10n.daemonLoadingStatus),
          ],
        ],
      ),
    );
  }

  Widget _buildNotAvailableNote() {
    final l10n = AppLocalizations.of(context);
    return ModernCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, color: AppTheme.colorsOf(context).warning),
          SizedBox(width: AppTheme.spacingS),
          Expanded(
            child: Text(
              l10n.daemonNotAvailableYet,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.colorsOf(context).textColor),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGeneralSettings() {
    final l10n = AppLocalizations.of(context);
    return ModernCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(l10n.settingsGeneralTitle, Icons.settings),
          SizedBox(height: AppTheme.spacingM),
          _buildSwitchTile(
            l10n.daemonEnableTray,
            BrandCopy.traySettingsHint,
            _enableSystemTray,
            null,
          ),
          _buildSwitchTile(
            l10n.daemonStartMinimized,
            l10n.daemonStartMinimizedSubtitle,
            _startMinimized,
            null,
          ),
          _buildSwitchTile(
            l10n.daemonEnableNotifications,
            l10n.daemonEnableNotificationsSubtitle,
            _enableNotifications,
            null,
          ),
          _buildSwitchTile(
            l10n.daemonAutoStart,
            l10n.daemonAutoStartSubtitle,
            _autoStartDaemon,
            null,
          ),
        ],
      ),
    );
  }

  Widget _buildAppearanceSettings() {
    final l10n = AppLocalizations.of(context);
    return ModernCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(l10n.appearanceScreenTitle, Icons.palette),
          SizedBox(height: AppTheme.spacingM),
          _buildDropdownTile(
            l10n.daemonTrayIconTheme,
            l10n.daemonTrayIconThemeSubtitle,
            _selectedTheme,
            ['system', 'light', 'dark', 'monochrome'],
            null,
          ),
        ],
      ),
    );
  }

  Widget _buildConnectionSettings() {
    final l10n = AppLocalizations.of(context);
    return ModernCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
              l10n.connectionSettingsTitle, Icons.network_check),
          SizedBox(height: AppTheme.spacingM),
          _buildSliderTile(
            l10n.daemonConnectionTimeout,
            l10n.daemonConnectionTimeoutSubtitle,
            _connectionTimeout.toDouble(),
            1.0,
            30.0,
            null,
          ),
          _buildSliderTile(
            l10n.daemonHealthCheckInterval,
            l10n.daemonHealthCheckIntervalSubtitle,
            _healthCheckInterval.toDouble(),
            10.0,
            300.0,
            null,
          ),
        ],
      ),
    );
  }

  /// Display label for a tray icon theme value; the stored value stays the
  /// untranslated key ('system', 'light', 'dark', 'monochrome').
  String _trayThemeLabel(String option) {
    final l10n = AppLocalizations.of(context);
    switch (option) {
      case 'system':
        return l10n.themeSystem;
      case 'light':
        return l10n.themeLight;
      case 'dark':
        return l10n.themeDark;
      case 'monochrome':
        return l10n.themeMonochrome;
      default:
        return option;
    }
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: AppTheme.colorsOf(context).primary, size: 24),
        SizedBox(width: AppTheme.spacingS),
        Text(
          title,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: AppTheme.colorsOf(context).textColor,
                fontWeight: FontWeight.bold,
              ),
        ),
      ],
    );
  }

  Widget _buildSwitchTile(
    String title,
    String subtitle,
    bool value,
    ValueChanged<bool>? onChanged,
  ) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: AppTheme.spacingS),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: AppTheme.colorsOf(context).textColor,
                        fontWeight: FontWeight.w500,
                      ),
                ),
                SizedBox(height: AppTheme.spacingXS),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.colorsOf(context).textColorLight,
                      ),
                ),
              ],
            ),
          ),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }

  Widget _buildDropdownTile(
    String title,
    String subtitle,
    String value,
    List<String> options,
    ValueChanged<String?>? onChanged,
  ) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: AppTheme.spacingS),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: AppTheme.colorsOf(context).textColor,
                  fontWeight: FontWeight.w500,
                ),
          ),
          SizedBox(height: AppTheme.spacingXS),
          Text(
            subtitle,
            style: Theme.of(
              context,
            )
                .textTheme
                .bodySmall
                ?.copyWith(color: AppTheme.colorsOf(context).textColorLight),
          ),
          SizedBox(height: AppTheme.spacingS),
          DropdownButtonFormField<String>(
            initialValue: value,
            decoration: InputDecoration(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.borderRadiusS),
              ),
              contentPadding: EdgeInsets.symmetric(
                horizontal: AppTheme.spacingM,
                vertical: AppTheme.spacingS,
              ),
            ),
            items: options.map((option) {
              return DropdownMenuItem(
                value: option,
                child: Text(_trayThemeLabel(option).toUpperCase()),
              );
            }).toList(),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildSliderTile(
    String title,
    String subtitle,
    double value,
    double min,
    double max,
    ValueChanged<double>? onChanged,
  ) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: AppTheme.spacingS),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: AppTheme.colorsOf(context).textColor,
                      fontWeight: FontWeight.w500,
                    ),
              ),
              Text(
                '${value.round()}',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.colorsOf(context).primary,
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ],
          ),
          SizedBox(height: AppTheme.spacingXS),
          Text(
            subtitle,
            style: Theme.of(
              context,
            )
                .textTheme
                .bodySmall
                ?.copyWith(color: AppTheme.colorsOf(context).textColorLight),
          ),
          SizedBox(height: AppTheme.spacingS),
          Slider(
            value: value,
            min: min,
            max: max,
            divisions: (max - min).round(),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildStatusRow(String label, String value, Color valueColor) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: AppTheme.spacingXS),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: Theme.of(
              context,
            )
                .textTheme
                .bodyMedium
                ?.copyWith(color: AppTheme.colorsOf(context).textColor),
          ),
          Flexible(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: valueColor,
                    fontWeight: FontWeight.w500,
                  ),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.hour.toString().padLeft(2, '0')}:'
        '${dateTime.minute.toString().padLeft(2, '0')}:'
        '${dateTime.second.toString().padLeft(2, '0')}';
  }
}
