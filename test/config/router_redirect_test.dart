import 'package:flutter_test/flutter_test.dart';
import 'package:pistisai/config/router_redirect.dart';

RouterRedirectInput _input({
  String location = '/',
  bool isAuthenticated = false,
  bool isAuthLoading = false,
  bool isWeb = false,
  bool isMobile = false,
  bool isAppSubdomain = false,
  bool isMarketingPath = false,
  bool hasCallbackParams = false,
  bool shouldShowDesktopWizard = false,
  bool shouldShowMobileConnection = false,
  bool requireCloudLogin = false,
}) {
  return RouterRedirectInput(
    location: location,
    isAuthenticated: isAuthenticated,
    isAuthLoading: isAuthLoading,
    isWeb: isWeb,
    isMobile: isMobile,
    isAppSubdomain: isAppSubdomain,
    isMarketingPath: isMarketingPath,
    hasCallbackParams: hasCallbackParams,
    shouldShowDesktopWizard: shouldShowDesktopWizard,
    shouldShowMobileConnection: shouldShowMobileConnection,
    requireCloudLogin: requireCloudLogin,
  );
}

void main() {
  group('resolveAppRedirect mobile vs desktop', () {
    test('first-run mobile root goes to the connection screen, not setup', () {
      expect(
        resolveAppRedirect(_input(
          location: '/',
          isMobile: true,
          shouldShowMobileConnection: true,
          shouldShowDesktopWizard: true,
        )),
        AppRoutePaths.connect,
      );
    });

    test('first-run desktop root goes to the setup wizard', () {
      expect(
        resolveAppRedirect(_input(
          location: '/',
          shouldShowDesktopWizard: true,
        )),
        AppRoutePaths.setup,
      );
    });

    test('first-run desktop chat redirects to the setup wizard', () {
      expect(
        resolveAppRedirect(_input(
          location: '/chat',
          shouldShowDesktopWizard: true,
        )),
        AppRoutePaths.setup,
      );
    });

    test('mobile never stays on the desktop setup wizard', () {
      expect(
        resolveAppRedirect(_input(
          location: '/setup',
          isMobile: true,
          shouldShowMobileConnection: true,
        )),
        AppRoutePaths.connect,
      );
    });

    test('desktop never stays on the mobile connection screen', () {
      expect(
        resolveAppRedirect(_input(
          location: '/connect',
          shouldShowDesktopWizard: true,
        )),
        AppRoutePaths.setup,
      );
    });

    test('connected mobile tailscale hub can use chat without login', () {
      expect(
        resolveAppRedirect(_input(
          location: '/chat',
          isMobile: true,
          shouldShowMobileConnection: false,
        )),
        isNull,
      );
    });

    test('pistisai.app mobile mode sends shell routes to login', () {
      expect(
        resolveAppRedirect(_input(
          location: '/chat',
          isMobile: true,
          requireCloudLogin: true,
        )),
        AppRoutePaths.login,
      );
    });

    test('authenticated mobile leaves the connection screen for chat', () {
      expect(
        resolveAppRedirect(_input(
          location: '/connect',
          isMobile: true,
          isAuthenticated: true,
        )),
        AppRoutePaths.chat,
      );
    });

    test('web app subdomain still sends unauthenticated shell to login', () {
      expect(
        resolveAppRedirect(_input(
          location: '/chat',
          isWeb: true,
          isAppSubdomain: true,
        )),
        AppRoutePaths.login,
      );
    });
  });
}
