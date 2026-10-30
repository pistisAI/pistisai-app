import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../services/connection_manager_service.dart';
import '../services/native_tray_service.dart'
    if (dart.library.html) '../services/native_tray_service_stub.dart';
import '../services/window_manager_service.dart'
    if (dart.library.html) '../services/window_manager_service_stub.dart';
import '../utils/logger.dart';
import '../utils/platform_helper.dart';

/// Ensures the native tray is configured once all required providers exist.
/// Enhanced with improved error handling and resource monitoring.
class TrayInitializer extends StatefulWidget {
  const TrayInitializer({
    required this.child,
    required this.navigatorKey,
    super.key,
  });

  final Widget child;
  final GlobalKey<NavigatorState> navigatorKey;

  @override
  State<TrayInitializer> createState() {
    debugPrint('[TrayInitializer] createState called');
    return _TrayInitializerState();
  }
}

class _TrayInitializerState extends State<TrayInitializer> {
  bool _trayInitialized = false;

  @override
  void initState() {
    super.initState();
    debugPrint('[TrayInitializer] initState called');
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Moved to build() to ensure the widget is fully mounted.
  }

  Future<void> _startTrayInit() async {
    if (_trayInitialized || kIsWeb || PlatformHelper.isMobile) {
      appLogger.info(
          '[TrayInitializer] Already initialized, web, or mobile, skipping');
      return;
    }
    _trayInitialized = true;

    appLogger.info('[TrayInitializer] Starting async tray init...');
    try {
      await _initializeTray(context);
      appLogger.info('[TrayInitializer] Tray init completed');
    } catch (e, st) {
      appLogger.error('[TrayInitializer] Tray init failed', error: e, stackTrace: st);
    }
  }

  Future<void> _initializeTray(BuildContext context) async {
    try {
      appLogger.info('[TrayInitializer] Starting tray initialization...');

      // ConnectionManagerService is an authenticated service that may not be available yet
      // Use Provider.of with listen: false to safely check if it's available
      ConnectionManagerService? connectionManager;
      try {
        connectionManager =
            Provider.of<ConnectionManagerService>(context, listen: false);
      } catch (e) {
        appLogger.info(
            '[TrayInitializer] ConnectionManagerService not available yet (user not authenticated)');
        connectionManager = null;
      }

      final windowManager = WindowManagerService();
      final nativeTray = NativeTrayService();

      appLogger.info('[TrayInitializer] Initializing window manager...');
      await windowManager.initialize();
      appLogger.info('[TrayInitializer] Window manager initialized');

      appLogger.info('[TrayInitializer] Initializing native tray...');
      final initialized = await nativeTray.initialize(
        connectionManager: connectionManager,
        onShowWindow: windowManager.showWindow,
        onHideWindow: windowManager.hideToTray,
        onSettings: () {
          final context = widget.navigatorKey.currentContext;
          if (context != null) {
            GoRouter.of(context).go('/settings');
          } else {
            appLogger.warning(
              '[TrayInitializer] Unable to navigate to settings: no context from navigatorKey',
            );
          }
        },
        onQuit: () async {
          appLogger.info('[TrayInitializer] Quit requested from tray');
          await windowManager.forceClose();
        },
      );
      appLogger.info('[TrayInitializer] Native tray initialized: $initialized');

      if (initialized) {
        appLogger.info('[TrayInitializer] Native tray initialized');
      } else {
        appLogger.info(
            '[TrayInitializer] Native tray not supported on this platform');
      }
    } catch (e, st) {
      appLogger.error('[TrayInitializer] Tray init failed',
          error: e, stackTrace: st);
    }
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('[TrayInitializer] build() called');
    
    // Initialize tray on first build after the widget is mounted.
    // We use a post-frame callback to ensure the widget tree is ready.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_trayInitialized) {
        unawaited(_startTrayInit());
      }
    });
    
    return widget.child;
  }
}
