import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../services/settings_preference_service.dart';

/// Opt-in switch for Zhipu / Moonshot / Gemini. Off by default (#647).
///
/// Provider registration is decided at authenticated-service bootstrap, so
/// turning this on applies from the next start. Turning it off is also
/// enforced on every cloud completion request.
class CloudLlmProvidersTile extends StatefulWidget {
  const CloudLlmProvidersTile({
    super.key,
    SettingsPreferenceService? preferences,
  }) : _preferences = preferences;

  final SettingsPreferenceService? _preferences;

  @override
  State<CloudLlmProvidersTile> createState() => _CloudLlmProvidersTileState();
}

class _CloudLlmProvidersTileState extends State<CloudLlmProvidersTile> {
  late final SettingsPreferenceService _preferences =
      widget._preferences ?? SettingsPreferenceService();
  bool? _enabled;
  bool _changed = false;
  bool _saveFailed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    bool value;
    try {
      value = await _preferences.isCloudLlmProvidersEnabled();
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
      await _preferences.setCloudLlmProvidersEnabled(value);
      if (mounted) setState(() => _changed = true);
    } catch (_) {
      if (mounted) {
        setState(() {
          _enabled = previous;
          _saveFailed = true;
        });
      }
    }
  }

  String get _subtitle {
    if (_saveFailed) {
      return 'Could not save this setting. Nothing was changed.';
    }
    if (_changed) {
      return _enabled == true
          ? 'On. Cloud providers register the next time the app starts. '
              'Prompts you send to them leave this device.'
          : 'Off. New cloud LLM calls are blocked immediately; fully '
              'unregistered the next time the app starts.';
    }
    return 'Off by default. When on, and only if this build includes their '
        'API keys, Zhipu/GLM, Moonshot/Kimi, and Google Gemini may receive '
        'the prompts you send them.';
  }

  @override
  Widget build(BuildContext context) {
    final enabled = _enabled;
    return Card(
      child: SwitchListTile(
        secondary: const Icon(Icons.cloud_outlined),
        title: Text(AppLocalizations.of(context).cloudLlmProvidersTitle),
        subtitle: Text(_subtitle),
        value: enabled ?? false,
        onChanged: enabled == null ? null : _set,
      ),
    );
  }
}
