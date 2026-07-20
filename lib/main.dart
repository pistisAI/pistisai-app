import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';
import 'package:pistisai/services/voice/voice_conversation_service.dart';
import 'package:pistisai/services/voice/local_voice_input_service.dart';
import 'package:pistisai/services/onboarding/setup_wizard_service.dart';

import 'package:pistisai/bootstrap/bootstrapper.dart';
import 'package:pistisai/config/app_config.dart';
import 'package:pistisai/config/router.dart';
import 'package:pistisai/config/theme.dart';

import 'package:pistisai/di/locator.dart' as di;
import 'package:pistisai/services/app_initialization_service.dart';
import 'package:pistisai/services/auth_service.dart';
import 'package:pistisai/services/connection_manager_service.dart';
import 'package:pistisai/services/desktop_client_detection_service.dart';
import 'package:pistisai/services/enhanced_user_tier_service.dart';
import 'package:pistisai/services/langchain_prompt_service.dart';
import 'package:pistisai/services/provider_configuration_manager.dart';
import 'package:pistisai/services/provider_discovery_service.dart';
import 'package:pistisai/services/streaming_chat_service.dart';
import 'package:pistisai/services/web_download_prompt_service.dart'
    if (dart.library.io) 'package:pistisai/services/web_download_prompt_service_stub.dart';
import 'package:pistisai/services/log_buffer_service.dart';
import 'package:pistisai/services/theme_provider.dart';
import 'package:pistisai/services/platform_detection_service.dart';
import 'package:camera_desktop/camera_desktop.dart'
    if (dart.library.html) 'package:camera_desktop/camera_desktop_stub.dart';
import 'package:pistisai/services/url_scheme_registration_service.dart'
    if (dart.library.html) 'package:pistisai/services/url_scheme_registration_service_stub.dart';
import 'web_plugins_stub.dart'
    if (dart.library.html) 'package:flutter_web_plugins/url_strategy.dart';
import 'package:pistisai/widgets/tray_initializer.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import 'package:pistisai/widgets/window_listener_widget.dart'
    if (dart.library.html) 'package:pistisai/widgets/window_listener_widget_stub.dart';
import 'package:pistisai/config/navigator_key.dart';
import 'package:pistisai/utils/platform_file_utils.dart'
    if (dart.library.html) 'package:pistisai/utils/platform_file_utils_web.dart';

// navigatorKey is now imported from config/navigator_key.dart

/// Resolve the OAuth callback URL from process arguments, if present.
///
/// Returns the first argument that looks like a Pistisai callback scheme
/// (`pistisai://` or `com.pistisai.app://`). Returns `null` when none of the
/// arguments are a callback URL — including when conventional engine/flutter
/// flags such as `--enable-logging` or `--verbose` are passed. This prevents
/// non-callback arguments from ever triggering the early `return` in [main]
/// that would skip `runApp` and leave the window black.
String? resolveCallbackUrl(List<String> args) {
  for (final a in args) {
    if (a.startsWith('com.pistisai.app://') || a.startsWith('pistisai://')) {
      return a;
    }
  }
  return null;
}

void main([List<String> args = const []]) async {
  // Flutter requires WidgetsFlutterBinding to be initialized first
  WidgetsFlutterBinding.ensureInitialized();

  // Register the desktop camera backend (Linux/macOS/Windows) for the
  // `camera` plugin. The official plugin has no Linux impl; camera_desktop
  // provides one via camera_platform_interface. No-op on web (stub).
  CameraDesktopPlugin.registerWith();

  // Immediate logging to verify Dart entry point is reached
  // Build trigger: force new release tag
  debugPrint('----- DART MAIN START ----- v1.0.0');

  // Handle command-line arguments (OAuth callback URLs).
  // Only bail out early when an actual callback URL is present; ignore
  // conventional engine/flutter flags (--enable-logging, --verbose, etc.)
  // so they cannot prevent the UI from ever starting.
  final callbackUrl = resolveCallbackUrl(args);
  if (callbackUrl != null) {
    debugPrint('[Main] Command-line arguments received: $args');
    await _handleCommandLineArgs(args);
    return; // Exit after handling callback
  }

  // Flutter requires WidgetsFlutterBinding to be initialized first
  // Moved inside runZonedGuarded in _runAppCommon to avoid Zone mismatch
  // WidgetsFlutterBinding.ensureInitialized();

  // Initialize Sentry IMMEDIATELY after Flutter binding (before all other services)
  debugPrint('[Main] Initializing Sentry...');

  // Sentry DSN is empty by default; set via --dart-define=SENTRY_DSN=...
  if (AppConfig.sentryDsn.isNotEmpty) {
    _runAppWithSentry();
  } else {
    debugPrint('[Main] Sentry DSN not configured, running without Sentry');
    unawaited(_registerWindowsUrlScheme());
    _initializeClientLogBuffer();
    _runAppCommon();
  }
}

Future<void> _registerWindowsUrlScheme() async {
  try {
    final registered = await UrlSchemeRegistrationService.registerUrlScheme();
    debugPrint('[Main] Windows URL scheme registration result: $registered');
  } catch (e) {
    debugPrint('[Main] Windows URL scheme registration failed: $e');
  }
}

/// Run the app with Sentry error tracking enabled.
/// Sentry DSN is configured via --dart-define=SENTRY_DSN=... at build time.
void _runAppWithSentry() {
  debugPrint('[Main] Running app with Sentry');
  _initializeClientLogBuffer();
  _runAppCommon();
}

void _runAppCommon() {
  Future<AppBootstrapData> loadApp() async {
    // Run the main bootstrap process
    try {
      debugPrint('[Main] Bootstrapper loading...');
      final bootstrapper = AppBootstrapper();
      final result = await bootstrapper.load();
      debugPrint('[Main] Bootstrapper loaded');
      return result;
    } catch (e, stack) {
      debugPrint('Bootstrap failed: $e');
      try {
        await Sentry.captureException(e, stackTrace: stack);
      } catch (_) {} // Ignore Sentry errors here
      // Return minimal bootstrap data to allow app to load error screen or retry
      return AppBootstrapData(isWeb: kIsWeb, supportsNativeShell: !kIsWeb);
    }
  }

  final appLoadFuture = loadApp();

  if (kIsWeb) {
    usePathUrlStrategy();
  }

  debugPrint('[Main] Starting runApp...');
  runApp(
    SentryWidget(
      child: PistisaiApp(bootstrapFuture: appLoadFuture),
    ),
  );
  debugPrint('[Main] runApp completed');
}

void _initializeClientLogBuffer() {
  if (!kIsWeb) {
    return;
  }

  final originalDebugPrint = debugPrint;
  debugPrint = (String? message, {int? wrapWidth}) {
    if (message != null) {
      LogBufferService.instance.add(message);
    }
    originalDebugPrint(message, wrapWidth: wrapWidth);
  };
}

/// Main application widget with comprehensive loading screen
class PistisaiApp extends StatefulWidget {
  final Future<AppBootstrapData>? bootstrapFuture;

  const PistisaiApp({super.key, this.bootstrapFuture});

  @override
  State<PistisaiApp> createState() => _PistisaiAppState();
}

class _PistisaiAppState extends State<PistisaiApp> {
  bool _authListenerAttached = false;
  AuthService? _attachedAuthService;

  @override
  void dispose() {
    if (_authListenerAttached && _attachedAuthService != null) {
      _attachedAuthService!.removeListener(_onAuthStateChanged);
    }
    super.dispose();
  }

  void _onAuthStateChanged() {
    // Rebuild when auth state changes so authenticated services can be provided
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('[App] build() called with FutureBuilder');

    if (widget.bootstrapFuture == null &&
        !di.serviceLocator.isRegistered<AuthService>()) {
      return MaterialApp(
        title: AppConfig.appName,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.system,
        home: const Scaffold(
          body: Center(child: Text('Pistisai')),
        ),
      );
    }

    return FutureBuilder<AppBootstrapData>(
      future: widget.bootstrapFuture ??
          Future.value(
              AppBootstrapData(isWeb: kIsWeb, supportsNativeShell: !kIsWeb)),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting ||
            !snapshot.hasData) {
          debugPrint('[App] Bootstrap loading, showing loading screen');
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: ThemeMode.system,
            home: Scaffold(
              backgroundColor: Colors.grey[900],
              body: const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                ),
              ),
            ),
          );
        }

        if (snapshot.hasError) {
          debugPrint('[App] Bootstrap error: ${snapshot.error}');
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            home: Scaffold(
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline,
                        size: 64, color: Colors.red),
                    const SizedBox(height: 16),
                    const Text('Initialization Error'),
                    const SizedBox(height: 8),
                    Text('${snapshot.error}'),
                  ],
                ),
              ),
            ),
          );
        }

        final bootstrap = snapshot.data!;
        debugPrint('[App] Bootstrap loaded, building app');
        return _buildAppWithBootstrap(bootstrap);
      },
    );
  }

  Widget _buildAppWithBootstrap(AppBootstrapData bootstrap) {
    _ensureAuthListener();

    // Build providers list - authenticated services will be added when registered
    // This rebuilds when auth state changes
    try {
      debugPrint('[App] Creating TrayInitializer...');
      final trayInitializer = TrayInitializer(
        navigatorKey: navigatorKey,
        child: const _AppRouterHost(),
      );
      debugPrint('[App] TrayInitializer created');

      debugPrint('[App] Building MultiProvider...');

      // Add providers one by one with debug
      final providersList = <SingleChildWidget>[];

      debugPrint('[App] Adding AuthService...');
      if (di.serviceLocator.isRegistered<AuthService>()) {
        providersList.add(ChangeNotifierProvider<AuthService>.value(
          value: di.serviceLocator.get<AuthService>(),
        ));
        debugPrint('[App] AuthService added');
      } else {
        debugPrint('[App] AuthService NOT registered!');
      }

      // Add other core services needed by HomeScreen
      _addProviderIfAvailable<StreamingChatService>(
          providersList, 'StreamingChatService');
      _addProviderIfAvailable<AppInitializationService>(
          providersList, 'AppInitializationService');
      _addProviderIfAvailable<ThemeProvider>(providersList, 'ThemeProvider');
      _addValueProviderIfAvailable<ProviderDiscoveryService>(
          providersList, 'ProviderDiscoveryService');
      _addValueProviderIfAvailable<ProviderConfigurationManager>(
          providersList, 'ProviderConfigurationManager');
      _addProviderIfAvailable<DesktopClientDetectionService>(
          providersList, 'DesktopClientDetectionService');
      _addProviderIfAvailable<WebDownloadPromptService>(
          providersList, 'WebDownloadPromptService');
      _addProviderIfAvailable<EnhancedUserTierService>(
          providersList, 'EnhancedUserTierService');
      _addProviderIfAvailable<ConnectionManagerService>(
          providersList, 'ConnectionManagerService');
      _addProviderIfAvailable<VoiceConversationService>(
          providersList, 'VoiceConversationService');
      _addProviderIfAvailable<LocalVoiceInputService>(
          providersList, 'LocalVoiceInputService');
      _addValueProviderIfAvailable<LangChainPromptService>(
          providersList, 'LangChainPromptService');
      _addProviderIfAvailable<PlatformDetectionService>(
          providersList, 'PlatformDetectionService');

        // Add Setup Wizard Service
      _addProviderIfAvailable<SetupWizardService>(
          providersList, 'SetupWizardService');

      debugPrint(
          '[App] Returning MultiProvider with ${providersList.length} providers');
      return MultiProvider(
        providers: providersList,
        child: trayInitializer,
      );
    } catch (e, stack) {
      debugPrint('[App] Error building providers: $e');
      debugPrint('[App] Stack: $stack');
      Sentry.captureException(e, stackTrace: stack);
      // Return error screen instead of crashing
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                const Text('Initialization Error'),
                const SizedBox(height: 8),
                Text(e.toString()),
              ],
            ),
          ),
        ),
      );
    }
  }

  void _ensureAuthListener() {
    if (_authListenerAttached) {
      return;
    }
    if (!di.serviceLocator.isRegistered<AuthService>()) {
      debugPrint(
          '[App] AuthService not registered yet - deferring listener attachment');
      return;
    }
    final authService = di.serviceLocator.get<AuthService>();
    authService.addListener(_onAuthStateChanged);
    _attachedAuthService = authService;
    _authListenerAttached = true;

    // Listen for authenticated services to load and trigger rebuild
    authService.areAuthenticatedServicesLoaded.addListener(() {
      if (authService.areAuthenticatedServicesLoaded.value && mounted) {
        debugPrint(
            '[App] Authenticated services became loaded, triggering rebuild...');
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(() {
              debugPrint(
                  '[App] Provider tree rebuilt with authenticated services');
            });
          }
        });
      }
    });

    // If authenticated services are already loaded, trigger a rebuild now
    if (authService.areAuthenticatedServicesLoaded.value) {
      debugPrint(
          '[App] Authenticated services already loaded, triggering rebuild...');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            debugPrint(
                '[App] Provider tree rebuilt with authenticated services');
          });
        }
      });
    }
  }

  void _addProviderIfAvailable<T extends ChangeNotifier>(
      List<SingleChildWidget> providers, String name) {
    try {
      if (di.serviceLocator.isRegistered<T>()) {
        final service = di.serviceLocator.get<T>();
        providers.add(ChangeNotifierProvider<T>.value(value: service));
        debugPrint('[App] $name added');
      } else {
        debugPrint('[App] $name not registered, skipping');
      }
    } catch (e) {
      debugPrint('[App] Error adding $name: $e');
    }
  }

  void _addValueProviderIfAvailable<T extends Object>(
      List<SingleChildWidget> providers, String name) {
    try {
      if (di.serviceLocator.isRegistered<T>()) {
        final service = di.serviceLocator.get<T>();
        providers.add(Provider<T>.value(value: service));
        debugPrint('[App] $name added');
      } else {
        debugPrint('[App] $name not registered, skipping');
      }
    } catch (e) {
      debugPrint('[App] Error adding $name: $e');
    }
  }
}

Future<void> _handleCommandLineArgs(List<String> args) async {
  debugPrint('[Main] Handling command-line arguments: $args');
  String? callbackUrl;
  for (final arg in args) {
    if (arg.startsWith('com.pistisai.app://') ||
        arg.startsWith('pistisai://')) {
      callbackUrl = arg;
      break;
    }
  }

  if (callbackUrl != null) {
    debugPrint('[Main] Found OAuth callback URL: $callbackUrl');
    if (!kIsWeb) {
      try {
        await PlatformFileUtils.writeCallbackFile(callbackUrl);
        debugPrint('[Main] Wrote callback URL to temp file');
      } catch (e) {
        debugPrint('[Main] Error writing callback file: $e');
      }
    }
  }
  debugPrint('[Main] Command-line handler exiting');
}

class _AppRouterHost extends StatefulWidget {
  const _AppRouterHost();

  @override
  State<_AppRouterHost> createState() => _AppRouterHostState();
}

class _AppRouterHostState extends State<_AppRouterHost> {
  GoRouter? _router;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _initialized) return;
      _initialized = true;
      _initializeRouterWhenReady();
    });
  }

  void _initializeRouterWhenReady() async {
    final authService = context.read<AuthService>();

    // Skip waiting for bootstrap - initialize router immediately
    debugPrint('[Router] Initializing without waiting for bootstrap');

    if (!mounted) return;
    _initializeRouter(authService);
  }

  @override
  Widget build(BuildContext context) {
    final router = _router;
    if (router == null) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.system,
        home: Scaffold(
          backgroundColor: Colors.grey[900],
          body: const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
            ),
          ),
        ),
      );
    }

    ThemeProvider? themeProvider;
    try {
      themeProvider = context.watch<ThemeProvider>();
    } catch (_) {}

    return WindowListenerWidget(
      child: MaterialApp.router(
        title: AppConfig.appName,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: themeProvider?.themeMode ?? ThemeMode.system,
        routerConfig: router,
        builder: (context, child) {
          // Error fallback
          if (child == null) {
            return const Scaffold(
              body: Center(
                child: Text('Loading...', style: TextStyle(fontSize: 18)),
              ),
            );
          }

          final mediaQuery = MediaQuery.of(context);
          return MediaQuery(
            data: mediaQuery.copyWith(
              textScaler: TextScaler.linear(
                mediaQuery.textScaler.scale(1.0).clamp(0.8, 1.2),
              ),
            ),
            child: child,
          );
        },
      ),
    );
  }

  void _initializeRouter(AuthService authService) {
    setState(() {
      _router = AppRouter.createRouter(
        navigatorKey: navigatorKey,
        authService: authService,
      );
    });
  }
}
// Deployment trigger 1770824833
