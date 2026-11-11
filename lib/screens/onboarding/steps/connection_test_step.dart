import 'package:pistisai/config/app_config.dart';
import 'package:flutter/material.dart';
import '../../../l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import 'package:pistisai/services/onboarding/setup_wizard_service.dart';
import '../../../config/theme.dart';

/// What the connection test step should show.
enum ConnectionTestView { testing, failed, verified, notTested }

/// Success is shown only for a test that really passed. "No error" alone is
/// not success: it is also the state before any test has run.
ConnectionTestView connectionTestView({
  required bool isLoading,
  required String? errorMessage,
  required bool verified,
}) {
  if (isLoading) return ConnectionTestView.testing;
  if (errorMessage != null) return ConnectionTestView.failed;
  return verified ? ConnectionTestView.verified : ConnectionTestView.notTested;
}

/// Connection Test Step
/// Tests connectivity to the selected provider
class ConnectionTestStep extends StatefulWidget {
  const ConnectionTestStep({super.key});

  @override
  State<ConnectionTestStep> createState() => _ConnectionTestStepState();
}

class _ConnectionTestStepState extends State<ConnectionTestStep> {
  @override
  void initState() {
    super.initState();
    // Auto-start test when step is shown
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Run whenever there is something to test and it has not already
      // passed; _runTest picks the URL the same way.
      final wizard = context.read<SetupWizardService>();
      if (!wizard.connectionVerified && !wizard.state.isLoading) {
        _runTest(wizard);
      }
    });
  }

  Future<void> _runTest(SetupWizardService wizard) async {
    final url = wizard.state.hermesUrl ??
        wizard.state.customUrl ??
        wizard.state.selectedProvider?.url ??
        AppConfig.gatewayUrl;
    await wizard.testConnection(url);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SetupWizardService>(
      builder: (context, wizard, child) {
        return Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Header
              ...switch (connectionTestView(
                isLoading: wizard.state.isLoading,
                errorMessage: wizard.state.errorMessage,
                verified: wizard.connectionVerified,
              )) {
                ConnectionTestView.testing => [_buildLoading(context)],
                ConnectionTestView.failed => [_buildError(context, wizard)],
                ConnectionTestView.verified => [
                    _buildSuccess(context, wizard)
                  ],
                ConnectionTestView.notTested => [
                    _buildNotTested(context, wizard)
                  ],
              },
            ],
          ),
        );
      },
    );
  }

  Widget _buildLoading(BuildContext context) {
    return Column(
      children: [
        const SizedBox(
          width: 64,
          height: 64,
          child: CircularProgressIndicator(),
        ),
        const SizedBox(height: 24),
        Text(
          AppLocalizations.of(context).connTesting,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 16),
        // Nothing is known until the test answers, so nothing is ticked.
        _buildTestItem(context, AppLocalizations.of(context).connDns, null),
        _buildTestItem(context, AppLocalizations.of(context).connTcp, null),
        _buildTestItem(
            context, AppLocalizations.of(context).connRuntimeApi, null),
      ],
    );
  }

  Widget _buildNotTested(BuildContext context, SetupWizardService wizard) {
    return Column(
      children: [
        Icon(
          Icons.help_outline,
          size: 64,
          color: AppTheme.colorsOf(context).textColorLight,
        ),
        const SizedBox(height: 24),
        Text(
          AppLocalizations.of(context).connNotTestedYet,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: () => _runTest(wizard),
          icon: const Icon(Icons.wifi_tethering),
          label: Text(AppLocalizations.of(context).connTestAction),
        ),
      ],
    );
  }

  Widget _buildError(BuildContext context, SetupWizardService wizard) {
    final provider = wizard.state.selectedProvider;
    final url = provider?.url ??
        wizard.state.customUrl ??
        AppLocalizations.of(context).connUnknown;

    return Column(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: AppTheme.colorsOf(context).danger.withValues(alpha: 0.05),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.error_outline,
            size: 40,
            color: AppTheme.colorsOf(context).danger,
          ),
        ),
        SizedBox(height: 24),
        Text(
          AppLocalizations.of(context).connFailed,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: AppTheme.colorsOf(context).danger,
              ),
        ),
        SizedBox(height: 16),
        Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.colorsOf(context).danger.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
                color:
                    AppTheme.colorsOf(context).danger.withValues(alpha: 0.2)),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Icon(Icons.info_outline,
                      color: AppTheme.colorsOf(context).danger, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      wizard.state.errorMessage ??
                          AppLocalizations.of(context).commonUnknownError,
                      style:
                          TextStyle(color: AppTheme.colorsOf(context).danger),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Retry button
        FilledButton.icon(
          onPressed: () => _runTest(wizard),
          icon: const Icon(Icons.refresh),
          label: Text(AppLocalizations.of(context).connRetry),
        ),
        const SizedBox(height: 16),

        // Go back option
        TextButton.icon(
          onPressed: () => wizard.previousStep(),
          icon: Icon(Icons.arrow_back),
          label: Text(AppLocalizations.of(context).connCheckSettings),
        ),

        SizedBox(height: 24),
        Text(
          AppLocalizations.of(context).connConnectingTo(url),
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontFamily: 'monospace',
                color: AppTheme.colorsOf(context).textColorLight,
              ),
        ),
      ],
    );
  }

  Widget _buildSuccess(BuildContext context, SetupWizardService wizard) {
    final provider = wizard.state.selectedProvider;

    return Column(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: AppTheme.colorsOf(context).success.withValues(alpha: 0.05),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.check_circle,
            size: 40,
            color: AppTheme.colorsOf(context).success,
          ),
        ),
        SizedBox(height: 24),
        Text(
          AppLocalizations.of(context).connSuccess,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: AppTheme.colorsOf(context).success,
              ),
        ),
        const SizedBox(height: 16),

        // Provider info card
        Container(
          width: double.infinity,
          constraints: const BoxConstraints(maxWidth: 400),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Theme.of(context).dividerColor,
            ),
          ),
          child: Column(
            children: [
              _buildTestItem(
                  context, AppLocalizations.of(context).connDns, true),
              _buildTestItem(
                  context, AppLocalizations.of(context).connTcp, true),
              _buildTestItem(
                  context, AppLocalizations.of(context).connRuntimeApi, true),
            ],
          ),
        ),
        const SizedBox(height: 24),

        if (provider != null) ...[
          Text(
            AppLocalizations.of(context).connConnectedTo,
            style: Theme.of(context).textTheme.labelMedium,
          ),
          const SizedBox(height: 8),
          Text(
            provider.name,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          Text(
            provider.url,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontFamily: 'monospace',
                  color: AppTheme.colorsOf(context).textColorLight,
                ),
          ),
        ],
      ],
    );
  }

  Widget _buildTestItem(BuildContext context, String label, bool? success) {
    final color = success == null
        ? AppTheme.colorsOf(context).textColorLight
        : success == true
            ? AppTheme.colorsOf(context).success
            : AppTheme.colorsOf(context).danger;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(
            success == null
                ? Icons.radio_button_unchecked
                : success == true
                    ? Icons.check_circle
                    : Icons.cancel,
            color: color,
            size: 20,
          ),
          const SizedBox(width: 12),
          Text(label),
        ],
      ),
    );
  }
}
