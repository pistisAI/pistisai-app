import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:logging/logging.dart';
import 'package:pistisai/config/app_config.dart';
import 'package:pistisai/services/onboarding/setup_wizard_service.dart';

final Logger _log = Logger('HermesUrlStep');

class HermesUrlStep extends StatefulWidget {
  const HermesUrlStep({super.key});

  @override
  State<HermesUrlStep> createState() => _HermesUrlStepState();
}

class _HermesUrlStepState extends State<HermesUrlStep> {
  final TextEditingController _urlController = TextEditingController();
  final TextEditingController _apiKeyController = TextEditingController();
  bool _autoDiscovered = false;
  bool _generatedKey = false;
  bool _isDiscovering = true;
  bool _initialized = false;

  @override
  void dispose() {
    _urlController.dispose();
    _apiKeyController.dispose();
    super.dispose();
  }

  void _syncFromWizard(SetupWizardService wizard) {
    final isRemote = wizard.state.hermesLocation == HermesLocation.tailscale;
    final url = wizard.state.hermesUrl ??
        (isRemote ? '' : AppConfig.defaultHermesUrl);
    if (_urlController.text != url) {
      _urlController.text = url;
    }
    final apiKey = wizard.state.hermesApiKey ?? '';
    if (_apiKeyController.text != apiKey) {
      _apiKeyController.text = apiKey;
    }
  }

  Future<void> _autoDiscoverApiKey(SetupWizardService wizard) async {
    if (wizard.state.hermesLocation == HermesLocation.tailscale) {
      if (mounted) {
        setState(() => _isDiscovering = false);
      }
      return;
    }

    final key = await wizard.discoverHermesApiKey();
    if (mounted) {
      setState(() {
        _isDiscovering = false;
        if (key != null && key.isNotEmpty) {
          _apiKeyController.text = key;
          _autoDiscovered = !key.startsWith('psk_');
          _generatedKey = key.startsWith('psk_');
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SetupWizardService>(
      builder: (context, wizard, child) {
        final isRemote = wizard.state.hermesLocation == HermesLocation.tailscale;

        if (!_initialized) {
          _initialized = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _syncFromWizard(wizard);
            if (wizard.state.hermesUrl != null &&
                wizard.state.hermesUrl!.isNotEmpty) {
              wizard.setHermesUrl(wizard.state.hermesUrl!);
            } else if (!isRemote) {
              wizard.setHermesUrl(_urlController.text);
            }
            _autoDiscoverApiKey(wizard);
          });
        } else {
          _syncFromWizard(wizard);
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                isRemote ? Icons.lan : Icons.smart_toy,
                size: 48,
                color: Theme.of(context).primaryColor,
              ),
              const SizedBox(height: 16),
              Text(
                isRemote ? 'Connect to remote Hermes' : 'Connect to Hermes Agent',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                isRemote
                    ? 'Confirm the Tailscale URL for your VPS or server, then enter the API key from that machine.'
                    : 'Hermes is running on this device. We auto-detected the connection details below.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey.shade600,
                    ),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _urlController,
                decoration: InputDecoration(
                  labelText: 'Hermes Agent URL',
                  hintText: isRemote
                      ? 'http://100.x.y.z:${AppConfig.defaultHermesPort}'
                      : AppConfig.defaultHermesUrl,
                  prefixIcon: const Icon(Icons.link),
                  border: const OutlineInputBorder(),
                ),
                onChanged: (value) {
                  wizard.setHermesUrl(value);
                },
              ),
              const SizedBox(height: 20),
              if (_isDiscovering)
                const Padding(
                  padding: EdgeInsets.only(bottom: 16),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      SizedBox(width: 12),
                      Text('Auto-detecting API key...'),
                    ],
                  ),
                )
              else
                TextField(
                  controller: _apiKeyController,
                  decoration: InputDecoration(
                    labelText: isRemote
                        ? 'Hermes API Key (required)'
                        : 'Hermes API Key',
                    hintText: isRemote
                        ? 'From API_SERVER_KEY on the remote server'
                        : 'Auto-discovered from Hermes config',
                    prefixIcon: const Icon(Icons.vpn_key),
                    suffixIcon: _autoDiscovered
                        ? Icon(Icons.check_circle, color: Colors.green.shade600)
                        : null,
                    border: const OutlineInputBorder(),
                  ),
                  obscureText: true,
                  onChanged: (value) {
                    wizard.setHermesApiKey(value);
                    if (_autoDiscovered) {
                      setState(() => _autoDiscovered = false);
                    }
                  },
                ),
              if (_autoDiscovered) ...[
                const SizedBox(height: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.auto_awesome,
                          size: 16, color: Colors.green.shade700),
                      const SizedBox(width: 8),
                      Text(
                        'Auto-discovered from Hermes configuration',
                        style: TextStyle(
                          color: Colors.green.shade800,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (isRemote) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Text(
                    'On the VPS, the API key is in ~/.hermes/.env as API_SERVER_KEY=.... '
                    'Copy that value here. Tailscale must be running on both this device and the server.',
                    style: TextStyle(color: Colors.blue.shade900, height: 1.35),
                  ),
                ),
              ],
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _urlController.text.isNotEmpty &&
                          (!isRemote || _apiKeyController.text.isNotEmpty)
                      ? () async {
                          wizard.setHermesUrl(_urlController.text);
                          wizard.setHermesApiKey(_apiKeyController.text);
                          _log.info('Hermes URL set: ${_urlController.text}');
                          if (!isRemote &&
                              _generatedKey &&
                              _apiKeyController.text.startsWith('psk_')) {
                            await wizard
                                .writeApiKeyToHermesEnv(_apiKeyController.text);
                          }
                          if (context.mounted) wizard.nextStep();
                        }
                      : null,
                  icon: const Icon(Icons.arrow_forward),
                  label: const Text('Save and Continue'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
