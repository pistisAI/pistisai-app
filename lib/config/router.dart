import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../config/theme.dart';
import '../services/auth_service.dart';
import '../services/streaming_chat_service.dart';

import '../screens/login_screen.dart';
import '../screens/callback_screen.dart';
import '../screens/onboarding/setup_wizard_screen.dart';
import '../screens/onboarding/mobile_connection_screen.dart';
import '../screens/home/home_layout.dart';
import '../widgets/navigation/app_navigation_shell.dart';
import '../services/onboarding/setup_wizard_service.dart';
import '../services/onboarding/mobile_connection_service.dart';
import '../utils/platform_helper.dart';
import 'router_redirect.dart';

// Settings screens are lazy-loaded
import '../screens/settings/settings_lazy.dart' as settings_lazy;

// GUI Automation screen (lazy-loaded)
import '../screens/gui_automation_lazy.dart' as gui_automation_lazy;

// Admin screens (lazy-loaded)
import '../screens/admin/admin_lazy.dart' as admin_lazy;

// Agent status screen is lazy-loaded
import '../screens/agent_status_lazy.dart' as agent_status_lazy;

// Dashboard screens (lazy-loaded)
import '../screens/dashboard_lazy.dart' as dashboard_lazy;

// Marketing screens (web-only) are lazy-loaded
import '../screens/marketing/marketing_lazy.dart' as marketing_lazy;

// Construction screen (lazy-loaded)
import '../screens/construction_lazy.dart' as construction_lazy;

// Overview screen
import '../screens/dashboard/overview_screen.dart';

// Channels screen
import '../screens/channels/channels_screen.dart';
import '../screens/channels/channel_detail_screen.dart';

// Usage screen
import '../screens/usage/usage_screen.dart';

// Instances screen
import '../screens/instances/instances_screen.dart';

// Sessions screen
import '../screens/sessions/sessions_screen.dart';

// Agents screen
import '../screens/agents/agents_screen.dart';

// Skills screen
import '../screens/skills/skills_screen.dart';

// Nodes screen
import '../screens/nodes/nodes_screen.dart';

// Cron Jobs screen
import '../screens/cron/cron_jobs_screen.dart';

// Logs screen
import '../screens/logs/logs_screen.dart';

// Debug screen
import '../screens/debug/debug_screen.dart';

// Config screen
import '../screens/config/config_screen.dart';
import '../config/app_config.dart';

/// Wrapper widget that provides HomeLayout with its required dependencies
class _HomeLayoutWrapper extends StatefulWidget {
  const _HomeLayoutWrapper();

  @override
  State<_HomeLayoutWrapper> createState() => _HomeLayoutWrapperState();
}

class _HomeLayoutWrapperState extends State<_HomeLayoutWrapper> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _handleSendMessage(StreamingChatService service, String message) {
    service.sendMessage(message);
  }

  @override
  Widget build(BuildContext context) {
    return HomeLayout(
      isCompact: false,
      scrollController: _scrollController,
      onSendMessage: _handleSendMessage,
    );
  }
}

/// Utility function to get the current hostname in web environment
String _getCurrentHostname() {
  if (kIsWeb) {
    try {
      return Uri.base.host;
    } catch (e) {
      return '';
    }
  }
  return '';
}

/// Check if current hostname indicates app subdomain
bool _isAppSubdomain() {
  if (!kIsWeb) return false;

  final hostname = _getCurrentHostname();
  final isApp = hostname.startsWith('app.') ||
      hostname == 'app.pistisai.app' ||
      hostname == 'localhost' ||
      hostname == '127.0.0.1';

  AppConfig.verboseLog('[Router] Hostname: $hostname, isApp: $isApp');
  return isApp;
}

bool _isMarketingPath(String location) {
  return location == '/' ||
      location == '/index.html' ||
      location == '/download' ||
      location == '/docs';
}

/// Helper to check for OAuth callback parameters (Supabase/generic)
bool _hasCallbackParameters(Uri uri) {
  return uri.queryParameters.containsKey('code') ||
      uri.queryParameters.containsKey('state') ||
      uri.queryParameters.containsKey('error') ||
      uri.queryParameters.containsKey('error_description');
}

/// Application router configuration using GoRouter
class AppRouter {
  static GoRouter createRouter({
    GlobalKey<NavigatorState>? navigatorKey,
    required AuthService authService,
    required SetupWizardService setupWizardService,
    required MobileConnectionService mobileConnectionService,
  }) {
    AppConfig.verboseLog('[Router] createRouter called');

    // For web, determine initial location thoughtfully
    String initialLocation = '/';
    if (kIsWeb) {
      final currentUri = Uri.base;
      if (_hasCallbackParameters(currentUri)) {
        AppConfig.verboseLog(
            '[Router] Initial URL has callback parameters, forcing /callback');
        initialLocation = '/callback?${currentUri.query}';
      } else {
        initialLocation = currentUri.path;
        if (currentUri.hasQuery) {
          initialLocation += '?${currentUri.query}';
        }
      }
    }
    AppConfig.verboseLog('[Router] Initial location: $initialLocation');

    final rootNavigatorKey = navigatorKey ?? GlobalKey<NavigatorState>();

    // Setup wizard redirect is handled in the redirect function below
    return GoRouter(
      navigatorKey: rootNavigatorKey,
      initialLocation: initialLocation,
      debugLogDiagnostics: true,
      refreshListenable: authService,
      routes: [
        // Setup Wizard route (desktop first-run; must be before shell route)
        GoRoute(
          path: '/setup',
          name: 'setup',
          pageBuilder: (context, state) => MaterialPage(
            key: state.pageKey,
            child: const SetupWizardScreen(),
          ),
        ),

        // Mobile connection screen (Android/iOS first-run; bypasses /setup)
        GoRoute(
          path: '/connect',
          name: 'connect',
          pageBuilder: (context, state) => MaterialPage(
            key: state.pageKey,
            child: const MobileConnectionScreen(),
          ),
        ),

        // Main app with StatefulShellRoute for indexed navigation
        StatefulShellRoute.indexedStack(
          builder: (context, state, navigationShell) {
            return AppNavigationShell(navigationShell: navigationShell);
          },
          branches: [
            // Chat (branch index 0)
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/chat',
                  pageBuilder: (context, state) => MaterialPage(
                    key: state.pageKey,
                    child: const _HomeLayoutWrapper(),
                  ),
                ),
              ],
            ),
            // Overview (branch index 1)
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/overview',
                  pageBuilder: (context, state) => MaterialPage(
                    key: state.pageKey,
                    child: const OverviewScreen(),
                  ),
                ),
              ],
            ),
            // Channels (branch index 2)
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/channels',
                  pageBuilder: (context, state) => MaterialPage(
                    key: state.pageKey,
                    child: const ChannelsScreen(),
                  ),
                  routes: [
                    GoRoute(
                      path: ':id',
                      pageBuilder: (context, state) => MaterialPage(
                        key: state.pageKey,
                        child: ChannelDetailScreen(
                          channelId: state.pathParameters['id']!,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            // Instances (branch index 3)
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/instances',
                  pageBuilder: (context, state) => MaterialPage(
                    key: state.pageKey,
                    child: const InstancesScreen(),
                  ),
                ),
              ],
            ),
            // Sessions (branch index 4)
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/sessions',
                  pageBuilder: (context, state) => MaterialPage(
                    key: state.pageKey,
                    child: const SessionsScreen(),
                  ),
                ),
              ],
            ),
            // Usage (branch index 5)
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/usage',
                  pageBuilder: (context, state) => MaterialPage(
                    key: state.pageKey,
                    child: const UsageScreen(),
                  ),
                ),
              ],
            ),
            // Cron Jobs (branch index 6)
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/cron',
                  pageBuilder: (context, state) => MaterialPage(
                    key: state.pageKey,
                    child: const CronJobsScreen(),
                  ),
                ),
              ],
            ),
            // Agents (branch index 7)
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/agents',
                  pageBuilder: (context, state) => MaterialPage(
                    key: state.pageKey,
                    child: const AgentsScreen(),
                  ),
                ),
              ],
            ),
            // Skills (branch index 8)
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/skills',
                  pageBuilder: (context, state) => MaterialPage(
                    key: state.pageKey,
                    child: const SkillsScreen(),
                  ),
                ),
              ],
            ),
            // Nodes (branch index 9)
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/nodes',
                  pageBuilder: (context, state) => MaterialPage(
                    key: state.pageKey,
                    child: const NodesScreen(),
                  ),
                ),
              ],
            ),
            // Config (branch index 10)
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/config',
                  pageBuilder: (context, state) => MaterialPage(
                    key: state.pageKey,
                    child: const ConfigScreen(),
                  ),
                ),
              ],
            ),
            // Debug (branch index 11)
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/debug',
                  pageBuilder: (context, state) => MaterialPage(
                    key: state.pageKey,
                    child: const DebugScreen(),
                  ),
                ),
              ],
            ),
            // Logs (branch index 12)
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/logs',
                  pageBuilder: (context, state) => MaterialPage(
                    key: state.pageKey,
                    child: const LogsScreen(),
                  ),
                ),
              ],
            ),
          ],
        ),

        // Login route
        GoRoute(
          path: '/login',
          name: 'login',
          pageBuilder: (context, state) => MaterialPage(
            key: state.pageKey,
            child: const LoginScreen(),
          ),
        ),

        // Callback route
        GoRoute(
          path: '/callback',
          name: 'callback',
          pageBuilder: (context, state) {
            if (!kIsWeb) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (context.mounted) context.go('/login');
              });
              return MaterialPage(
                key: state.pageKey,
                child:
                    Scaffold(body: Center(child: CircularProgressIndicator())),
              );
            }

            final params = state.uri.queryParameters.isNotEmpty
                ? state.uri.queryParameters
                : Uri.base.queryParameters;
            return MaterialPage(
              key: state.pageKey,
              child: CallbackScreen(queryParams: params),
            );
          },
        ),

        // Marketing & Other routes
        ...marketing_lazy.marketingRoutes,
        ...settings_lazy.settingsRoutes,
        ...admin_lazy.adminRoutes,
        ...agent_status_lazy.agentStatusRoutes,
        ...dashboard_lazy.dashboardRoutes,
        ...gui_automation_lazy.guiAutomationRoutes,
        ...construction_lazy.constructionRoutes,
      ],
      redirect: (context, state) async {
        AppConfig.verboseLog(
            '[Router] Redirect check: ${state.matchedLocation}');

        final location = state.matchedLocation;
        final isCallback = location == AppRoutePaths.callback;
        final hasCallbackParams = _hasCallbackParameters(state.uri) ||
            (kIsWeb && _hasCallbackParameters(Uri.base));
        if (hasCallbackParams && !isCallback && kIsWeb) {
          AppConfig.verboseLog(
              '[Router] Redirecting to /callback to process params');
          final params = state.uri.queryParameters.isNotEmpty
              ? state.uri.queryParameters
              : Uri.base.queryParameters;
          return Uri(path: AppRoutePaths.callback, queryParameters: params)
              .toString();
        }

        final isMobile = PlatformHelper.isMobile;
        final shouldShowDesktopWizard =
            !kIsWeb && !isMobile && await setupWizardService.shouldShowWizard();
        final shouldShowMobileConnection = isMobile &&
            await mobileConnectionService.shouldShowConnectionScreen();

        final next = resolveAppRedirect(
          RouterRedirectInput(
            location: location,
            isAuthenticated: authService.isAuthenticated.value,
            isAuthLoading: authService.isLoading.value,
            isWeb: kIsWeb,
            isMobile: isMobile,
            isAppSubdomain: _isAppSubdomain(),
            isMarketingPath: _isMarketingPath(location),
            hasCallbackParams: false,
            shouldShowDesktopWizard: shouldShowDesktopWizard,
            shouldShowMobileConnection: shouldShowMobileConnection,
            requireCloudLogin: mobileConnectionService.requireCloudLogin,
          ),
        );
        if (next != null) {
          AppConfig.verboseLog('[Router] Redirecting $location -> $next');
        }
        return next;
      },
      errorBuilder: (context, state) => Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 64,
                color: AppTheme.colorsOf(context).danger,
              ),
              const SizedBox(height: 16),
              Text(
                'Page Not Found',
                style: TextStyle(
                  fontSize: 24,
                  color: AppTheme.colorsOf(context).textColor,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => context.go('/'),
                child: const Text('Go Home'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Trigger build: Force full application build to package and verify the android tesseract_ocr duplicate class build fix.
