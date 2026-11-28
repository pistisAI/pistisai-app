import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../brand/brand.dart';
import '../../di/locator.dart' as di;
import '../../l10n/app_localizations.dart';
import '../../services/cloud_connector_service.dart';
import '../../services/settings_preference_service.dart';

/// Opt-in switch for the hosted cloud service. Off by default.
///
/// Reads and writes [SettingsPreferenceService.isCloudServicesEnabled], the
/// preference that gates device registration and heartbeat
/// ([CloudConnectorService]), brain sync and chat history sync. Brain sync and
/// chat history read it at each call. Device registration runs once at
/// startup, so this tile starts it when the user turns the switch on and
/// stops the heartbeat when it is turned off.
///
/// Turning it on asks for confirmation first, listing what will be sent.
class CloudServicesTile extends StatefulWidget {
  const CloudServicesTile({
    super.key,
    SettingsPreferenceService? preferences,
    CloudConnectorService? connector,
  })  : _preferences = preferences,
        _connector = connector;

  final SettingsPreferenceService? _preferences;
  final CloudConnectorService? _connector;

  @override
  State<CloudServicesTile> createState() => _CloudServicesTileState();
}

enum _Changed { none, onRegistered, onPending, off }

class _CloudServicesTileState extends State<CloudServicesTile> {
  late final SettingsPreferenceService _preferences =
      widget._preferences ?? SettingsPreferenceService();
  bool? _enabled;
  _Changed _changed = _Changed.none;
  bool _saveFailed = false;
  bool _busy = false;

  CloudConnectorService? get _connector {
    final injected = widget._connector;
    if (injected != null) return injected;
    if (di.serviceLocator.isRegistered<CloudConnectorService>()) {
      return di.serviceLocator<CloudConnectorService>();
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    bool value;
    try {
      value = await _preferences.isCloudServicesEnabled();
    } catch (_) {
      value = false;
    }
    if (mounted) setState(() => _enabled = value);
  }

  Future<void> _onChanged(bool value) async {
    if (_busy) return;
    if (value) {
      final confirmed = await showCloudServicesConsentDialog(context);
      if (!confirmed || !mounted) return;
    }
    await _save(value);
  }

  Future<void> _save(bool value) async {
    final previous = _enabled;
    setState(() {
      _busy = true;
      _saveFailed = false;
    });
    try {
      await _preferences.setCloudServicesEnabled(value);
    } catch (_) {
      if (mounted) {
        setState(() {
          _enabled = previous;
          _saveFailed = true;
          _busy = false;
        });
      }
      return;
    }
    if (mounted) setState(() => _enabled = value);

    var changed = _Changed.off;
    final connector = _connector;
    if (value) {
      var registered = false;
      if (connector != null) {
        try {
          registered = await connector.registerAndStart();
        } catch (_) {
          registered = false;
        }
      }
      changed = registered ? _Changed.onRegistered : _Changed.onPending;
    } else {
      connector?.stop();
    }
    if (mounted) {
      setState(() {
        _changed = changed;
        _busy = false;
      });
    }
  }

  String _subtitle(AppLocalizations l10n) {
    final product = Brand.current.productName;
    if (_saveFailed) return l10n.cloudServicesSaveFailed;
    switch (_changed) {
      case _Changed.onRegistered:
        return l10n.cloudServicesSubtitleOnRegistered(product);
      case _Changed.onPending:
        return l10n.cloudServicesSubtitleOnPending(product);
      case _Changed.off:
        return l10n.cloudServicesSubtitleOff(product);
      case _Changed.none:
        return l10n.cloudServicesSubtitleDefault(product);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final enabled = _enabled;
    return Card(
      child: SwitchListTile(
        secondary: const Icon(Icons.cloud_sync_outlined),
        title: Text(l10n.cloudServicesTitle),
        subtitle: Text(_subtitle(l10n)),
        value: enabled ?? false,
        onChanged: (enabled == null || _busy) ? null : _onChanged,
      ),
    );
  }
}

/// Asks the user to confirm turning on cloud services. Returns true only when
/// they choose to turn it on; dismissing or cancelling returns false.
Future<bool> showCloudServicesConsentDialog(BuildContext context) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => const CloudServicesConsentDialog(),
  );
  return result ?? false;
}

/// Lists what the app sends to the cloud service while the switch is on.
class CloudServicesConsentDialog extends StatelessWidget {
  const CloudServicesConsentDialog({super.key, this.isWeb = kIsWeb});

  /// Whether to add the note that the web app stores chat history on the
  /// server regardless of this switch.
  final bool isWeb;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final product = Brand.current.productName;
    final items = <String>[
      l10n.cloudServicesDialogDeviceRegistration,
      l10n.cloudServicesDialogBrainSync,
      l10n.cloudServicesDialogChatHistory,
    ];
    return AlertDialog(
      title: Text(l10n.cloudServicesDialogTitle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.cloudServicesDialogIntro(product)),
            const SizedBox(height: 12),
            for (final item in items)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(right: 8),
                      child: Text('•'),
                    ),
                    Expanded(child: Text(item)),
                  ],
                ),
              ),
            if (isWeb) ...[
              Text(l10n.cloudServicesDialogWebNote),
              const SizedBox(height: 8),
            ],
            const SizedBox(height: 4),
            Text(l10n.cloudServicesDialogOutro),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l10n.cloudServicesDialogCancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(l10n.cloudServicesDialogConfirm),
        ),
      ],
    );
  }
}
