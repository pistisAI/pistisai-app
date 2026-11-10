import 'package:flutter/material.dart';

import '../../config/app_config.dart';
import '../../services/settings_preference_service.dart';

/// Opt-in switch for crash reports. Off by default.
///
/// The crash-reporting client starts only at launch and only when this is
/// on, so a change applies from the next start. Turning it off also stops
/// Dart error events at once (see `main.dart`).
class CrashReportingTile extends StatefulWidget {
  const CrashReportingTile({
    super.key,
    SettingsPreferenceService? preferences,
    bool? reportingConfigured,
  })  : _preferences = preferences,
        _reportingConfigured = reportingConfigured;

  final SettingsPreferenceService? _preferences;

  /// Whether this build can send reports at all (a DSN was compiled in).
  final bool? _reportingConfigured;

  @override
  State<CrashReportingTile> createState() => _CrashReportingTileState();
}

class _CrashReportingTileState extends State<CrashReportingTile> {
  late final SettingsPreferenceService _preferences =
      widget._preferences ?? SettingsPreferenceService();
  bool? _enabled;
  bool _changed = false;
  bool _saveFailed = false;

  bool get _configured =>
      widget._reportingConfigured ?? AppConfig.sentryDsn.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    bool value;
    try {
      value = await _preferences.isCrashReportingEnabled();
    } catch (_) {
      value = false;
    }
    if (mounted) setState(() => _enabled = value);
  }

  Future<void> _set(bool value) async {
    final previous = _enabled;
    setState(() {
      _enabled = value;
      _saveFailed = false;
    });
    try {
      await _preferences.setCrashReportingEnabled(value);
      if (mounted) setState(() => _changed = true);
    } catch (_) {
      // Show the real state rather than a switch that did not save.
      if (mounted) {
        setState(() {
          _enabled = previous;
          _saveFailed = true;
        });
      }
    }
  }

  String get _subtitle {
    if (!_configured) {
      return 'This build cannot send crash reports, so this setting has '
          'no effect.';
    }
    if (_saveFailed) {
      return 'Could not save this setting. Nothing was changed.';
    }
    if (_changed) {
      return _enabled == true
          ? 'On. Reports start the next time the app starts.'
          : 'Off. Fully applied the next time the app starts.';
    }
    return 'Off by default. When on, error details and stack traces are '
        'sent to the developers when the app crashes.';
  }

  @override
  Widget build(BuildContext context) {
    final enabled = _enabled;
    return Card(
      child: SwitchListTile(
        secondary: const Icon(Icons.bug_report_outlined),
        title: const Text('Send crash reports'),
        subtitle: Text(_subtitle),
        value: enabled ?? false,
        onChanged: (enabled == null || !_configured) ? null : _set,
      ),
    );
  }
}
