import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:pistisai/brand/brand_copy.dart';
import 'package:pistisai/config/app_config.dart';
import 'package:pistisai/config/theme.dart';
import 'package:pistisai/di/locator.dart' as di;
import 'package:pistisai/screens/onboarding/widgets/connection_method_card.dart';
import 'package:pistisai/services/auth_service.dart';
import 'package:pistisai/services/onboarding/mobile_connection_service.dart';
import 'package:provider/provider.dart';

/// First-run screen for Android/iOS. The phone is a client of the desktop hub.
class MobileConnectionScreen extends StatefulWidget {
  const MobileConnectionScreen({super.key});

  @override
  State<MobileConnectionScreen> createState() => _MobileConnectionScreenState();
}

class _MobileConnectionScreenState extends State<MobileConnectionScreen> {
  final TextEditingController _hostController = TextEditingController();
  MobileConnectionMode? _selected;
  bool _connecting = false;

  @override
  void dispose() {
    _hostController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.colorsOf(context);
    return Scaffold(
      body: SafeArea(
        child: Consumer<MobileConnectionService>(
          builder: (context, connection, _) {
            return LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
                  child: ConstrainedBox(
                    constraints:
                        BoxConstraints(minHeight: constraints.maxHeight - 56),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Icon(
                          Icons.phonelink,
                          size: 56,
                          color: Theme.of(context).primaryColor,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Connect this phone',
                          style: Theme.of(context).textTheme.headlineSmall,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Your desktop app is the hub. This phone does not install Hermes — it joins that hub.',
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: colors.textColorLight,
                                  ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 28),
                        ConnectionMethodCard(
                          icon: Icons.shield_outlined,
                          title: 'Self-Hosted via Tailscale',
                          description:
                              'Reach the desktop hub on your tailnet. Install Tailscale on this phone first.',
                          selected:
                              _selected == MobileConnectionMode.tailscaleHub,
                          onTap: () => setState(() {
                            _selected = MobileConnectionMode.tailscaleHub;
                          }),
                        ),
                        const SizedBox(height: 12),
                        ConnectionMethodCard(
                          icon: Icons.cloud_outlined,
                          title: BrandCopy.cloudConnectedTitle,
                          description: BrandCopy.cloudConnectedBody,
                          selected:
                              _selected == MobileConnectionMode.pistisaiApp,
                          onTap: () => setState(() {
                            _selected = MobileConnectionMode.pistisaiApp;
                          }),
                        ),
                        const SizedBox(height: 24),
                        if (_selected == MobileConnectionMode.tailscaleHub)
                          _buildTailscaleForm(context, connection),
                        if (_selected == MobileConnectionMode.pistisaiApp)
                          _buildCloudForm(context, connection),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildTailscaleForm(
    BuildContext context,
    MobileConnectionService connection,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Desktop Tailscale MagicDNS name',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _hostController,
          autocorrect: false,
          keyboardType: TextInputType.url,
          decoration: InputDecoration(
            hintText: 'pc-name.tailnet.ts.net',
            helperText:
                'Same tailnet as the PC. Android allows cleartext only to *.ts.net. Hermes stays on port ${AppConfig.defaultHermesPort}.',
          ),
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: _connecting ? null : () => _connectTailscale(connection),
          child: _connecting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Connect to desktop hub'),
        ),
        if (connection.errorMessage != null) ...[
          const SizedBox(height: 12),
          Text(
            connection.errorMessage!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
      ],
    );
  }

  Widget _buildCloudForm(
    BuildContext context,
    MobileConnectionService connection,
  ) {
    return FilledButton(
      onPressed: _connecting ? null : () => _connectCloud(connection),
      child: Text(BrandCopy.cloudContinue),
    );
  }

  Future<void> _connectTailscale(MobileConnectionService connection) async {
    setState(() => _connecting = true);
    try {
      final result =
          await connection.connectViaTailscaleHub(_hostController.text);
      if (!mounted) {
        return;
      }
      if (!result.success) {
        return;
      }
      await _bootstrapLocalServices();
      if (!mounted) {
        return;
      }
      context.go('/chat');
    } finally {
      if (mounted) {
        setState(() => _connecting = false);
      }
    }
  }

  Future<void> _connectCloud(MobileConnectionService connection) async {
    setState(() => _connecting = true);
    try {
      await connection.connectViaPistisaiApp();
      if (!mounted) {
        return;
      }
      context.go('/login');
    } finally {
      if (mounted) {
        setState(() => _connecting = false);
      }
    }
  }

  Future<void> _bootstrapLocalServices() async {
    try {
      await di.setupAuthenticatedServices();
      if (di.serviceLocator.isRegistered<AuthService>()) {
        di.serviceLocator
            .get<AuthService>()
            .areAuthenticatedServicesLoaded
            .value = true;
      }
    } catch (e) {
      debugPrint('[MobileConnectionScreen] Authenticated services: $e');
    }
  }
}
