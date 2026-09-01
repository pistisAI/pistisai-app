import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../di/locator.dart' as di;
import '../../services/cloud_connector_service.dart';

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
      final devices = await di.serviceLocator<CloudConnectorService>()
          .listDevices();
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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Revoke device?'),
        content: Text(
          'Revoke ${device.deviceName ?? device.deviceId}? The device will '
          'need to re-register to reconnect.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Revoke'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    var ok = false;
    try {
      ok = await di.serviceLocator<CloudConnectorService>()
          .revokeDevice(device.deviceId);
    } catch (_) {
      ok = false;
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(ok ? 'Device revoked' : 'Failed to revoke device')),
    );
    if (ok) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final connector = di.serviceLocator<CloudConnectorService>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Device Mesh'),
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
                      ? Colors.green
                      : Colors.grey,
                ),
                title: const Text('This device'),
                subtitle: Text(_connectionLabel(connector.status)),
              ),
            ),
            const SizedBox(height: 16),
            Text('Registered devices', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            if (_loading)
              const Center(child: CircularProgressIndicator())
            else if (_error != null)
              Column(
                children: [
                  Text('Failed to load devices', style: theme.textTheme.bodyMedium),
                  const SizedBox(height: 8),
                  FilledButton.tonal(onPressed: _load, child: const Text('Retry')),
                ],
              )
            else if (_devices == null || _devices!.isEmpty)
              const Text('No other devices registered.')
            else
              ..._devices!.map(_deviceCard),
          ],
        ),
      ),
    );
  }

  String _connectionLabel(CloudConnectionStatus status) {
    switch (status) {
      case CloudConnectionStatus.connected:
        return 'Connected to cloud connector';
      case CloudConnectionStatus.connecting:
        return 'Connecting…';
      case CloudConnectionStatus.error:
        return 'Connection error';
      case CloudConnectionStatus.disconnected:
        return 'Disconnected';
    }
  }

  Widget _deviceCard(CloudDevice device) {
    final online = device.status == 'online';
    final lastSeen = device.lastSeen != null
        ? DateFormat.yMd().add_jm().format(device.lastSeen!.toLocal())
        : 'never';
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(
          online ? Icons.devices : Icons.phonelink_off,
          color: online ? Colors.green : null,
        ),
        title: Text(device.deviceName ?? device.deviceId),
        subtitle: Text(
          '${device.platform ?? 'unknown platform'} · ${device.runtimeLocation}'
          '\n${online ? "online" : "last seen $lastSeen"}'
          '${device.runtimeAvailable ? " · runtime available" : ""}',
        ),
        isThreeLine: true,
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline),
          tooltip: 'Revoke',
          onPressed: () => _revoke(device),
        ),
      ),
    );
  }
}
