import 'package:flutter/material.dart';
import '../../../l10n/app_localizations.dart';
import '../../../config/theme.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:logging/logging.dart';
import 'package:pistisai/config/app_config.dart';
import 'package:pistisai/services/hermes/hermes_endpoint_resolver.dart';
import 'package:pistisai/services/onboarding/setup_wizard_service.dart';

final Logger _log = Logger('HermesUrlStep');

/// Command to run on the Hermes host once you are logged into the VPS.
String hermesRemoteApiKeyOnServerCommand() =>
    "grep '^API_SERVER_KEY=' ~/.hermes/.env | cut -d= -f2-";

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
  bool _isResolvingEndpoint = false;
  bool _initialized = false;

  @override
  void dispose() {
    _urlController.dispose();
    _apiKeyController.dispose();
    super.dispose();
  }

  String _localHermesSubtitle(SetupWizardService wizard, bool isRemote) {
    if (isRemote) {
      return AppLocalizations.of(context).urlRemoteSubtitle;
    }
    if (_isResolvingEndpoint) {
      return AppLocalizations.of(context).urlLooking;
    }
    if (wizard.state.detectedHermesKind == HermesEndpointKind.agentApi) {
      return AppLocalizations.of(context).urlDetected;
    }
    final detection = wizard.state.hermesDetectionMessage;
    if (detection != null && detection.isNotEmpty) {
      return detection;
    }
    return AppLocalizations.of(context)
        .urlEnterLocal('${AppConfig.defaultHermesPort}');
  }

  void _syncFromWizard(SetupWizardService wizard) {
    final isRemote = wizard.state.hermesLocation == HermesLocation.tailscale;
    final url =
        wizard.state.hermesUrl ?? (isRemote ? '' : AppConfig.defaultHermesUrl);
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
        final isRemote =
            wizard.state.hermesLocation == HermesLocation.tailscale;

        if (!_initialized) {
          _initialized = true;
          _isResolvingEndpoint = !isRemote;
          WidgetsBinding.instance.addPostFrameCallback((_) async {
            if (!isRemote) {
              await wizard.resolveLocalHermes();
            } else {
              _syncFromWizard(wizard);
              if (wizard.state.hermesUrl != null &&
                  wizard.state.hermesUrl!.isNotEmpty) {
                wizard.setHermesUrl(wizard.state.hermesUrl!);
              }
            }
            if (!mounted) {
              return;
            }
            setState(() => _isResolvingEndpoint = false);
            await _autoDiscoverApiKey(wizard);
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
                isRemote
                    ? AppLocalizations.of(context).urlConnectRemote
                    : AppLocalizations.of(context).urlConnectLocal,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                _localHermesSubtitle(wizard, isRemote),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: wizard.state.detectedHermesKind ==
                              HermesEndpointKind.desktopDashboard
                          ? Theme.of(context).colorScheme.error
                          : AppTheme.colorsOf(context).textColorLight,
                    ),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _urlController,
                decoration: InputDecoration(
                  labelText: AppLocalizations.of(context).urlLabel,
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
                Padding(
                  padding: EdgeInsets.only(bottom: 16),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      SizedBox(width: 12),
                      Text(AppLocalizations.of(context).urlAutoDetectingKey),
                    ],
                  ),
                )
              else
                TextField(
                  controller: _apiKeyController,
                  decoration: InputDecoration(
                    labelText: isRemote
                        ? AppLocalizations.of(context).urlApiKeyRequired
                        : AppLocalizations.of(context).urlApiKey,
                    hintText: isRemote
                        ? AppLocalizations.of(context).urlApiKeyRemoteHint
                        : AppLocalizations.of(context).urlApiKeyLocalHint,
                    prefixIcon: const Icon(Icons.vpn_key),
                    suffixIcon: _autoDiscovered
                        ? Icon(Icons.check_circle,
                            color: AppTheme.colorsOf(context).success)
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
                    color: AppTheme.colorsOf(context)
                        .success
                        .withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: AppTheme.colorsOf(context)
                            .success
                            .withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.auto_awesome,
                          size: 16, color: AppTheme.colorsOf(context).success),
                      const SizedBox(width: 8),
                      Text(
                        AppLocalizations.of(context).urlAutoDiscovered,
                        style: TextStyle(
                          color: AppTheme.colorsOf(context).success,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (isRemote) ...[
                const SizedBox(height: 16),
                const _RemoteApiKeyHelp(),
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
                  label: Text(AppLocalizations.of(context).urlSaveContinue),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _RemoteApiKeyHelp extends StatelessWidget {
  const _RemoteApiKeyHelp();

  Future<void> _copyCommand(BuildContext context, String command) async {
    await Clipboard.setData(ClipboardData(text: command));
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppLocalizations.of(context).urlCommandCopied),
        duration: Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final command = hermesRemoteApiKeyOnServerCommand();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.colorsOf(context).info.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
            color: AppTheme.colorsOf(context).info.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppLocalizations.of(context).urlRemoteHelp,
            style:
                TextStyle(color: AppTheme.colorsOf(context).info, height: 1.35),
          ),
          const SizedBox(height: 10),
          _CommandBlock(
            command: command,
            onCopy: () => _copyCommand(context, command),
          ),
        ],
      ),
    );
  }
}

class _CommandBlock extends StatelessWidget {
  const _CommandBlock({
    required this.command,
    required this.onCopy,
  });

  final String command;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppTheme.colorsOf(context).textColor,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
            color: AppTheme.colorsOf(context).info.withValues(alpha: 0.1)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: SelectableText(
              command,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                height: 1.35,
              ),
            ),
          ),
          IconButton(
            tooltip: AppLocalizations.of(context).urlCopyCommand,
            onPressed: onCopy,
            icon: Icon(Icons.copy,
                size: 18, color: AppTheme.colorsOf(context).info),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}
