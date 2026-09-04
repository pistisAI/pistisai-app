import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:pistisai/services/onboarding/setup_wizard_service.dart';
import 'package:pistisai/utils/logger.dart';
import 'package:pistisai/screens/onboarding/steps/welcome_step.dart';
import 'package:pistisai/screens/onboarding/steps/connection_method_step.dart';
import 'package:pistisai/screens/onboarding/steps/local_detection_step.dart';
import 'package:pistisai/screens/onboarding/steps/gateway_password_step.dart';
import 'package:pistisai/screens/onboarding/steps/tailscale_discovery_step.dart';
import 'package:pistisai/screens/onboarding/steps/remote_connection_step.dart';
import 'package:pistisai/screens/onboarding/steps/hermes_location_step.dart';
import 'package:pistisai/screens/onboarding/steps/hermes_url_step.dart';
import 'package:pistisai/screens/onboarding/steps/connection_test_step.dart';
import 'package:pistisai/screens/onboarding/steps/completion_step.dart';

/// Setup Wizard Screen
/// Guides new users through OpenClaw Gateway configuration
class SetupWizardScreen extends StatefulWidget {
  const SetupWizardScreen({super.key});

  @override
  State<SetupWizardScreen> createState() => _SetupWizardScreenState();
}

class _SetupWizardScreenState extends State<SetupWizardScreen> {
  final PageController _pageController = PageController();
  int _lastStep = 0;
  ConnectionMethod? _lastMethod;
  HermesLocation? _lastHermesLocation;
  String? _lastErrorSnackbarMessage;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  /// Get total steps based on connection method
  int _getTotalSteps(ConnectionMethod? method, HermesLocation? hermesLocation) {
    return _buildSteps(method, hermesLocation).length;
  }

  bool _stepListChanged(ConnectionMethod? method, HermesLocation? hermesLocation) {
    return _lastMethod != method || _lastHermesLocation != hermesLocation;
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SetupWizardService>(
      builder: (context, wizard, child) {
        final method = wizard.state.selectedMethod;
        final hermesLocation = wizard.state.hermesLocation;
        final totalSteps = _getTotalSteps(method, hermesLocation);
        final currentStep = wizard.state.currentStep;

        if (_stepListChanged(method, hermesLocation)) {
          _lastMethod = method;
          _lastHermesLocation = hermesLocation;
          _lastStep = currentStep;
          // Don't animate on method change, just jump to current step
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_pageController.hasClients && currentStep < totalSteps) {
              _pageController.jumpToPage(currentStep);
            }
          });
        }
        // Listen for step changes and animate page
        else if (currentStep != _lastStep) {
          _lastStep = currentStep;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_pageController.hasClients && currentStep < totalSteps) {
              _pageController.animateToPage(
                currentStep,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
              );
            }
          });
        }

        return Scaffold(
          body: SafeArea(
            child: Column(
              children: [
                _buildProgressIndicator(currentStep, totalSteps),
                Expanded(
                  child: PageView(
                    key: ValueKey('pageview_${method}_$hermesLocation'),
                    controller: _pageController,
                    physics: const NeverScrollableScrollPhysics(),
                    onPageChanged: (index) {
                      wizard.goToStep(index);
                    },
                    children: _buildSteps(method, hermesLocation),
                  ),
                ),
                if (wizard.state.errorMessage != null &&
                    method == ConnectionMethod.hermes)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
                    child: Text(
                      wizard.state.errorMessage!,
                      style: TextStyle(color: Theme.of(context).colorScheme.error),
                      textAlign: TextAlign.center,
                    ),
                  ),
                _buildNavigationButtons(wizard, totalSteps),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildProgressIndicator(int currentStep, int totalSteps) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 12),
      child: Column(
        children: [
          Row(
            children: List.generate(
              totalSteps,
              (index) => Expanded(
                child: Container(
                  height: 4,
                  margin: EdgeInsets.only(
                    right: index < totalSteps - 1 ? 8 : 0,
                  ),
                  decoration: BoxDecoration(
                    color: index <= currentStep
                        ? Theme.of(context).primaryColor
                        : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Step ${currentStep + 1} of $totalSteps',
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ],
      ),
    );
  }

  List<Widget> _buildSteps(
    ConnectionMethod? method,
    HermesLocation? hermesLocation,
  ) {
    if (method == ConnectionMethod.hermes) {
      final steps = <Widget>[
        const WelcomeStep(),
        const ConnectionMethodStep(),
        const HermesLocationStep(),
      ];
      if (hermesLocation == HermesLocation.tailscale) {
        steps.add(const TailscaleDiscoveryStep());
      }
      steps.addAll(const [
        HermesUrlStep(),
        ConnectionTestStep(),
        CompletionStep(),
      ]);
      return steps;
    }

    // OpenClaw flow
    final steps = <Widget>[
      const WelcomeStep(), // 0 - Always shown
      const ConnectionMethodStep(), // 1 - Always shown
      const LocalDetectionStep(), // 2 - Always shown
      const GatewayPasswordStep(), // 3 - Always shown
    ];

    // Step 4: TailscaleDiscoveryStep - only for tailscale method
    if (method == ConnectionMethod.tailscale) {
      steps.add(const TailscaleDiscoveryStep());
    }

    // Step 5: RemoteConnectionStep - only for custom method
    if (method == ConnectionMethod.custom) {
      steps.add(const RemoteConnectionStep());
    }

    // Remaining steps - always shown
    steps.addAll([
      const ConnectionTestStep(),
      const CompletionStep(),
    ]);

    return steps;
  }

  void _showCompletionError(String message) {
    if (!mounted) return;

    if (_lastErrorSnackbarMessage == message) {
      return;
    }

    _lastErrorSnackbarMessage = message;
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 5),
      ),
    );
  }

  Widget _buildNavigationButtons(SetupWizardService wizard, int totalSteps) {
    final currentStep = wizard.state.currentStep;
    final isFirstStep = currentStep == 0;
    final isLastStep = currentStep == totalSteps - 1;

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: Theme.of(context).dividerColor,
          ),
        ),
      ),
      child: Row(
        children: [
          if (isFirstStep)
            TextButton(
              onPressed: wizard.state.isLoading
                  ? null
                  : () async {
                      await wizard.deferSetup();
                      if (mounted) {
                        context.go('/chat');
                      }
                    },
              child: const Text('Set up later'),
            )
          else
            Expanded(
              child: OutlinedButton(
                onPressed: () {
                  wizard.previousStep();
                },
                child: const Text('Back'),
              ),
            ),
          if (!isFirstStep) const SizedBox(width: 16),
          Expanded(
            child: FilledButton(
              onPressed: wizard.state.isLoading
                  ? null
                  : () async {
                      if (isLastStep) {
                        _lastErrorSnackbarMessage = null;
                        final success = await wizard.completeSetup();

                        if (!success) {
                          final message = wizard.state.errorMessage ??
                              'Setup could not be completed right now. Please try again.';
                          _showCompletionError(message);
                          appLogger.warning(
                            '[SetupWizard] Setup completion failed at final step: $message',
                          );
                          return;
                        }

                        _lastErrorSnackbarMessage = null;

                        if (mounted) {
                          context.go('/');
                        }
                        return;
                      }

                      wizard.nextStep();
                    },
              child: Text(
                isLastStep
                    ? 'Complete'
                    : wizard.state.isLoading
                        ? 'Loading...'
                        : 'Next',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
