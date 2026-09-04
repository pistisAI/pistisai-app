import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';

import 'auth_provider.dart';
import 'providers/local_auth_provider.dart';
import 'providers/supabase_auth_provider.dart';

/// Factory for creating the right authentication provider based on context.
///
/// - Desktop (default): `LocalAuthProvider` — works offline, no cloud deps.
/// - Desktop with `CLOUD_ENABLED` env var: `SupabaseAuthProvider`.
/// - Web: always `SupabaseAuthProvider` (web needs cloud auth).
///
/// Cloud is optional. The local app is free to download and use.
class AuthProviderFactory {
  static AuthProvider create() {
    if (kIsWeb) {
      debugPrint('[AuthProviderFactory] Web: using SupabaseAuthProvider');
      return SupabaseAuthProvider();
    }

    // On desktop, check for cloud opt-in
    final cloudEnabled =
        Platform.environment['CLOUD_ENABLED']?.toLowerCase() == 'true';

    if (cloudEnabled) {
      debugPrint(
          '[AuthProviderFactory] Desktop (cloud): using SupabaseAuthProvider');
      return SupabaseAuthProvider();
    }

    debugPrint('[AuthProviderFactory] Desktop (local): using LocalAuthProvider');
    return LocalAuthProvider();
  }
}
