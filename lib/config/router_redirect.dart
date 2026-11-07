/// Pure redirect rules for desktop vs mobile vs web.
///
/// Mobile (Android/iOS) first-run goes to [connectPath], not the desktop
/// setup wizard. Desktop first-run still goes to [setupPath].
class RouterRedirectInput {
  const RouterRedirectInput({
    required this.location,
    required this.isAuthenticated,
    required this.isAuthLoading,
    required this.isWeb,
    required this.isMobile,
    required this.isAppSubdomain,
    required this.isMarketingPath,
    required this.hasCallbackParams,
    required this.shouldShowDesktopWizard,
    required this.shouldShowMobileConnection,
    required this.requireCloudLogin,
  });

  final String location;
  final bool isAuthenticated;
  final bool isAuthLoading;
  final bool isWeb;
  final bool isMobile;
  final bool isAppSubdomain;
  final bool isMarketingPath;
  final bool hasCallbackParams;
  final bool shouldShowDesktopWizard;
  final bool shouldShowMobileConnection;
  final bool requireCloudLogin;
}

class AppRoutePaths {
  static const String root = '/';
  static const String chat = '/chat';
  static const String login = '/login';
  static const String callback = '/callback';
  static const String setup = '/setup';
  static const String connect = '/connect';
}

bool isAppShellRoute(String location) {
  return location.startsWith('/chat') ||
      location.startsWith('/overview') ||
      location.startsWith('/channels') ||
      location.startsWith('/instances') ||
      location.startsWith('/sessions') ||
      location.startsWith('/usage') ||
      location.startsWith('/cron') ||
      location.startsWith('/agents') ||
      location.startsWith('/skills') ||
      location.startsWith('/nodes') ||
      location.startsWith('/config') ||
      location.startsWith('/debug') ||
      location.startsWith('/logs');
}

bool isAdminRoute(String location) {
  return location.startsWith('/admin') || location == '/admin-center';
}

/// Returns a new location, or `null` to keep [RouterRedirectInput.location].
String? resolveAppRedirect(RouterRedirectInput input) {
  final location = input.location;
  final isLoggingIn = location == AppRoutePaths.login;
  final isCallback = location == AppRoutePaths.callback;
  final isSetup = location == AppRoutePaths.setup;
  final isConnect = location == AppRoutePaths.connect;
  final isShellRoute = isAppShellRoute(location);

  if (isAdminRoute(location) && !input.isWeb) {
    return AppRoutePaths.chat;
  }

  if (input.hasCallbackParams && !isCallback && input.isWeb) {
    return AppRoutePaths.callback;
  }

  if (input.isAuthLoading && !isCallback && !isSetup && !isConnect) {
    return null;
  }

  if (input.isWeb && !input.isAppSubdomain) {
    if (input.isMarketingPath) {
      return null;
    }
    return AppRoutePaths.root;
  }

  if (location == AppRoutePaths.root) {
    if (_mobileNeedsConnection(input)) {
      return AppRoutePaths.connect;
    }
    // Desktop first-run must hit the setup wizard before chat/coach.
    if (!input.isWeb && input.shouldShowDesktopWizard) {
      return AppRoutePaths.setup;
    }
    if (input.isAuthenticated || !input.isWeb || input.isAppSubdomain) {
      return AppRoutePaths.chat;
    }
    return null;
  }

  if (input.isAuthenticated) {
    // Do not let a local/desktop session skip unfinished first-run setup.
    if (!input.isWeb && input.shouldShowDesktopWizard && !isSetup) {
      return AppRoutePaths.setup;
    }
    if (isLoggingIn || isConnect || isSetup) {
      return AppRoutePaths.chat;
    }
    return null;
  }

  if (input.isMobile) {
    if (isSetup || (_mobileNeedsConnection(input) && !isConnect)) {
      return AppRoutePaths.connect;
    }
    if (input.requireCloudLogin) {
      if (isLoggingIn || isCallback || isConnect) {
        return null;
      }
      if (isShellRoute) {
        return AppRoutePaths.login;
      }
      return null;
    }
    return null;
  }

  if (!input.isWeb) {
    if (isConnect) {
      return input.shouldShowDesktopWizard
          ? AppRoutePaths.setup
          : AppRoutePaths.chat;
    }
    if (!isSetup && input.shouldShowDesktopWizard) {
      return AppRoutePaths.setup;
    }
    return null;
  }

  if (isLoggingIn || isCallback || isSetup) {
    return null;
  }
  if (isConnect) {
    return AppRoutePaths.login;
  }
  if (isShellRoute) {
    return AppRoutePaths.login;
  }
  return null;
}

bool _mobileNeedsConnection(RouterRedirectInput input) {
  return input.isMobile &&
      !input.isAuthenticated &&
      input.shouldShowMobileConnection;
}
