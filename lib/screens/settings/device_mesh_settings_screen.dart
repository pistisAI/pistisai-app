import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../config/theme.dart';
import '../../di/locator.dart' as di;
import '../../services/cloud_connector_service.dart';
import '../../l10n/app_localizations.dart';

/// Device Mesh Settings — lists the user's registered cloud devices,
/// their presence/runtime state, and allows revoking them.
class DeviceMeshSettingsScreen extends StatefulWidget {
  const DeviceMeshSettingsScreen({super.key});

  @override
  State<DeviceMeshSettingsScreen> createState() =>
      _DeviceMeshSettingsScreenState();
}

class _DeviceMeshSettingsScreenState extends State<DeviceMeshSettingsScreen> {
  List<CloudDevice>? _devices;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final devices =
          await di.serviceLocator<CloudConnectorService>().listDevices();
      if (!mounted) return;
      setState(() {
        _devices = devices;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _revoke(CloudDevice device) async {
    // Read the strings before any await so no BuildContext is used across
    // an async gap.
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.meshRevokeTitle),
        content: Text(
          l10n.meshRevokeBody(device.deviceName ?? device.deviceId),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.meshRevoke),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    var ok = false;
    try {
      ok = await di
          .serviceLocator<CloudConnectorService>()
          .revokeDevice(device.deviceId);
    } catch (_) {
      ok = false;
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? l10n.meshRevoked : l10n.meshRevokeFailed),
      ),
    );
    if (ok) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final connector = di.serviceLocator<CloudConnectorService>();

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.meshTitle),
        elevation: 0,
        leading: BackButton(
          onPressed: () => context.go('/settings/connection'),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: ListTile(
                leading: Icon(
                  Icons.cloud_done,
                  color: connector.status == CloudConnectionStatus.connected
                      ? AppTheme.colorsOf(context).success
                      : AppTheme.colorsOf(context).textColorLight,
                ),
                title: Text(l10n.meshThisDevice),
                subtitle: Text(_connectionLabel(connector.status)),
              ),
            ),
            const SizedBox(height: 16),
            Text(l10n.meshRegisteredDevices,
                style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            if (_loading)
              const Center(child: CircularProgressIndicator())
            else if (_error != null)
              Column(
                children: [
                  Text(l10n.meshLoadFailed, style: theme.textTheme.bodyMedium),
                  const SizedBox(height: 8),
                  FilledButton.tonal(
                    onPressed: _load,
                    child: Text(l10n.commonRetry),
                  ),
                ],
              )
            else if (_devices == null || _devices!.isEmpty)
              Text(l10n.meshNoDevices)
            else
              ..._devices!.map(_deviceCard),
          ],
        ),
      ),
    );
  }

  String _connectionLabel(CloudConnectionStatus status) {
    final l10n = AppLocalizations.of(context);
    switch (status) {
      case CloudConnectionStatus.connected:
        return l10n.meshStatusConnected;
      case CloudConnectionStatus.connecting:
        return l10n.meshStatusConnecting;
      case CloudConnectionStatus.error:
        return l10n.meshStatusError;
      case CloudConnectionStatus.disconnected:
        return l10n.meshStatusDisconnected;
    }
  }

  Widget _deviceCard(CloudDevice device) {
    final l10n = AppLocalizations.of(context);
    final online = device.status == 'online';
    final lastSeen = device.lastSeen != null
        ? DateFormat.yMd().add_jm().format(device.lastSeen!.toLocal())
        : l10n.meshNever;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(
          online ? Icons.devices : Icons.phonelink_off,
          color: online ? AppTheme.colorsOf(context).success : null,
        ),
        title: Text(device.deviceName ?? device.deviceId),
        subtitle: Text(
          '${device.platform ?? l10n.meshUnknownPlatform} · ${device.runtimeLocation}\n'
          '${online ? l10n.meshOnline : l10n.meshLastSeen(lastSeen)}'
          '${device.runtimeAvailable ? ' · ${l10n.meshRuntimeAvailable}' : ''}',
        ),
        isThreeLine: true,
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline),
          tooltip: l10n.meshRevoke,
          onPressed: () => _revoke(device),
        ),
      ),
    );
  }
}
