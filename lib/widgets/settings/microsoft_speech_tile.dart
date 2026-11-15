import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../services/settings_preference_service.dart';

/// Opt-in switch for Microsoft online speech (edge-tts). Off by default (#647).
class MicrosoftSpeechTile extends StatefulWidget {
  const MicrosoftSpeechTile({
    super.key,
    SettingsPreferenceService? preferences,
  }) : _preferences = preferences;

  final SettingsPreferenceService? _preferences;

  @override
  State<MicrosoftSpeechTile> createState() => _MicrosoftSpeechTileState();
}

class _MicrosoftSpeechTileState extends State<MicrosoftSpeechTile> {
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
      value = await _preferences.isMicrosoftSpeechEnabled();
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
      await _preferences.setMicrosoftSpeechEnabled(value);
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
          ? 'On. Spoken reply text may be sent to Microsoft speech.'
          : 'Off. Online speech calls are blocked immediately.';
    }
    return 'Off by default. When on, text read aloud with the online voice '
        'is sent to Microsoft\'s speech service via edge-tts. Local TTS '
        'stays available either way.';
  }

  @override
  Widget build(BuildContext context) {
    final enabled = _enabled;
    return Card(
      child: SwitchListTile(
        secondary: const Icon(Icons.record_voice_over_outlined),
        title: Text(AppLocalizations.of(context).microsoftSpeechTitle),
        subtitle: Text(_subtitle),
        value: enabled ?? false,
        onChanged: enabled == null ? null : _set,
      ),
    );
  }
}
