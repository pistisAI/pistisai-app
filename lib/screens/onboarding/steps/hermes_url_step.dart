import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:logging/logging.dart';
import 'package:pistisai/config/app_config.dart';
import 'package:pistisai/services/onboarding/setup_wizard_service.dart';

final Logger _log = Logger('HermesUrlStep');

class HermesUrlStep extends StatefulWidget {
  final String? hermesUrl;
  final String? hermesApiKey;

  const HermesUrlStep({
    super.key,
    this.hermesUrl,
    this.hermesApiKey,
  });

  @override
  State<HermesUrlStep> createState() => _HermesUrlStepState();
}

class _HermesUrlStepState extends State<HermesUrlStep> {
  final TextEditingController _urlController = TextEditingController();
  final TextEditingController _apiKeyController = TextEditingController();
  bool _autoDiscovered = false;
  bool _isDiscovering = true;

  @override
  void initState() {
    super.initState();
    _urlController.text = widget.hermesUrl ?? AppConfig.defaultHermesUrl;
    _apiKeyController.text = widget.hermesApiKey ?? '';
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SetupWizardService>().setHermesUrl(_urlController.text);
      _autoDiscoverApiKey();
    });
  }

  Future<void> _autoDiscoverApiKey() async {
    final wizard = context.read<SetupWizardService>();
    final key = await wizard.discoverHermesApiKey();
    if (mounted) {
      setState(() {
        _isDiscovering = false;
        if (key != null && key.isNotEmpty) {
          _apiKeyController.text = key;
          _autoDiscovered = true;
        }
      });
    }
  }

  @override
  void dispose() {
    _urlController.dispose();
    _apiKeyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Icon(
            Icons.smart_toy,
            size: 48,
            color: Theme.of(context).primaryColor,
          ),
          const SizedBox(height: 16),
          Text(
            'Connect to Hermes Agent',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Hermes is running on your machine. We auto-detected the connection details below.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey.shade600,
                ),
          ),
          const SizedBox(height: 32),

          // URL field
          TextField(
            controller: _urlController,
            decoration: InputDecoration(
              labelText: 'Hermes Agent URL',
              hintText: AppConfig.defaultHermesUrl,
              prefixIcon: const Icon(Icons.link),
              border: const OutlineInputBorder(),
            ),
            onChanged: (value) {
              context.read<SetupWizardService>().setHermesUrl(value);
            },
          ),
          const SizedBox(height: 20),

          // API Key field - auto-discovered
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
                labelText: 'Hermes API Key',
                hintText: 'Auto-discovered from Hermes config',
                prefixIcon: const Icon(Icons.vpn_key),
                suffixIcon: _autoDiscovered
                    ? Icon(Icons.check_circle, color: Colors.green.shade600)
                    : null,
                border: const OutlineInputBorder(),
              ),
              obscureText: true,
              onChanged: (value) {
                if (_autoDiscovered) {
                  setState(() => _autoDiscovered = false);
                }
              },
            ),

          // Auto-discovered badge
          if (_autoDiscovered) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.auto_awesome, size: 16, color: Colors.green.shade700),
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

          const SizedBox(height: 32),

          // Save button
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _urlController.text.isNotEmpty
                  ? () {
                      context
                          .read<SetupWizardService>()
                          .setHermesUrl(_urlController.text);
                      _log.info('Hermes URL set: ${_urlController.text}');
                      context.read<SetupWizardService>().nextStep();
                    }
                  : null,
              icon: const Icon(Icons.arrow_forward),
              label: const Text('Save and Continue'),
            ),
          ),
        ],
      ),
    );
  }
}
