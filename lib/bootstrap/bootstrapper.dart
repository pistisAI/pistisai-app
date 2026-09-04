import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/app_config.dart';
import '../di/locator.dart';

/// Data returned by [AppBootstrapper] after the core environment is ready.
class AppBootstrapData {
  AppBootstrapData({required this.isWeb, required this.supportsNativeShell});

  final bool isWeb;
  final bool supportsNativeShell;
}

/// Handles the one-time initialization that must occur before the widget tree
/// is built.  This ensures heavy setup only happens once at application start.
class AppBootstrapper {
  AppBootstrapper();

  Future<AppBootstrapData> load() async {
    try {
      debugPrint('[Bootstrapper] Starting bootstrap process...');

      await _initializeSupabase();

      debugPrint('[Bootstrapper] Setting up service locator...');
      await setupServiceLocator().timeout(
        const Duration(seconds: 25),
        onTimeout: () {
          debugPrint(
              '[Bootstrapper] Service locator setup timed out after 25s; continuing with degraded startup');
        },
      );
      debugPrint('[Bootstrapper] Service locator setup completed');

      debugPrint('[Bootstrapper] Bootstrap completed successfully');
      return AppBootstrapData(isWeb: kIsWeb, supportsNativeShell: !kIsWeb);
    } catch (e, stack) {
      debugPrint('[Bootstrapper] ERROR during bootstrap: $e');
      debugPrint('[Bootstrapper] Stack trace: $stack');

      // Re-throw to let the caller handle it
      rethrow;
    }
  }

  /// Initialize Supabase before the service locator builds the auth provider.
  /// `Supabase.initialize` is idempotent — it skips re-initialization on a
  /// subsequent call (e.g. hot restart).
  Future<void> _initializeSupabase() async {
    debugPrint('[Bootstrapper] Initializing Supabase...');
    await Supabase.initialize(
      url: AppConfig.supabaseUrl,
      publishableKey: AppConfig.supabasePublishableKey,
    );
    debugPrint('[Bootstrapper] Supabase initialized');
  }
}
