import '../config/app_config.dart';
import 'brand.dart';
import 'brand_config.dart';

/// User-facing sentences assembled from the active brand.
///
/// Screens read these instead of embedding the upstream product name.
class BrandCopy {
  BrandCopy._();

  static BrandConfig get brand => Brand.current;

  static String get welcomeTitle => 'Welcome to ${brand.productName}';
  static String get aboutTitle => 'About ${brand.productName}';
  static String get trayShow => 'Show ${brand.productName}';
  static String trayTooltip(String status) => '${brand.productName} - $status';
  static String get loginSubtitle =>
      "I'm ${brand.productName}, your AI assistant.";
  static String get chatWelcome =>
      "Welcome to ${brand.productName}! I'm ready to help you with any questions or tasks. What would you like to talk about?";
  static String get settingsAboutSubtitle =>
      '${brand.productName} and this build';
  static String get agentMonitorTitle => '${brand.productName} Agent Monitor';
  static String get traySettingsHint =>
      'Show ${brand.productName} icon in system tray';
  static String get desktopRequiredBody =>
      'Please use the ${brand.productName} desktop application for the best experience.';
  static String get docsLinkDescription =>
      'Learn how to use ${brand.productName}';
  static String get voiceCompanionBody =>
      'Natural conversation state, backend switching, and agent control for the ${brand.productName} voice shell layered around Hermes.';
  static String get hermesLocationHint =>
      'For a remote VPS, install Tailscale on the server and this device, then pick the server from your tailnet. ${brand.productName} connects over the private Tailscale IP.';
  static String hermesDesktopDashboard(String url) =>
      'Hermes desktop is running at $url, but its agent API is not available there. '
      '${brand.productName} needs /health on port ${AppConfig.defaultHermesPort}.';
  static String hubUnreachable(String host) =>
      'Could not reach a ${brand.productName} desktop hub at $host. Open Tailscale on this phone, join the same tailnet as your PC, and use that PC\'s Tailscale name or 100.x address.';
  static String get testEmailSubject => 'Test Email from ${brand.productName}';
  static String get startMenuHint =>
      'Find ${brand.productName} in your Start menu or desktop shortcut.';
  static String get macDragHint =>
      'Drag ${brand.productName} to your Applications folder.';
  static String get macLaunchHint =>
      'Find ${brand.productName} in your Applications folder and launch it.';
  static String get downloadTitle => 'Download ${brand.productName}';
  static String get downloadDescription =>
      'Download the latest version of ${brand.productName} for your platform';
  static String get installBlurb =>
      'Install ${brand.productName} and your Aiman with a single command.';
  static String get packageInstalling => 'Installing ${brand.packageTitle}...';
  static String get minimizeHint =>
      '${brand.productName} will minimize to the system tray by default. Look for the LLM icon in your system tray.';
  static String get webProxyHint =>
      'Web: Uses ${brand.productName} streaming proxy automatically';
  static String get porticoLine =>
      '${brand.productName} builds a portico worthy of her return. ';
  static String get urlProtocolLabel => 'URL:${brand.productName} Protocol';
  static String get pillarsLine =>
      'Four pillars hold ${brand.productName} together.';
  static String get stoaLine =>
      'Like the Stoa Poikile, ${brand.productName} is a space held up by four pillars, ';
  static String get existsLine => brand.closingLine;
  static String get cloudContinue => 'Continue with ${brand.websiteDomain}';
  static String get cloudConnectedTitle =>
      'Connected via ${brand.websiteDomain}';
  static String get cloudConnectedBody =>
      'Sign in and sync through the ${brand.websiteDomain} gateway.';
  static String get installSh => 'https://${brand.websiteDomain}/install.sh';
  static String get installPs1 => 'https://${brand.websiteDomain}/install.ps1';

  /// On-disk names the build still emits. Brand files do not rename these.
  static const String shippedLinuxBinary = 'pistisai';
  static const String shippedWindowsExe = 'Pistisai.exe';

  static String get exeDoubleClick =>
      'Navigate to the extracted folder and double-click $shippedWindowsExe.';
  static String get quarantineHint =>
      'Remove quarantine attribute: xattr -d com.apple.quarantine /Applications/${brand.productName}.app';

  /// Homepage story. The default brand keeps the Pistis narrative.
  static String get landingNarrative => brand.id == 'pistisai'
      ? '${porticoLine}Four pillars that together restore what was lost: '
          'private, local, trustworthy AI.'
      : brand.aboutText;

  /// Strings a non-default brand must not fill with the upstream product name.
  static List<String> routedSamples() {
    return <String>[
      brand.productName,
      brand.shortName,
      brand.companyName,
      brand.tagline,
      brand.supportEmail,
      brand.supportUrl,
      brand.privacyEmail,
      brand.websiteDomain,
      brand.websiteUrl,
      brand.appUrl,
      brand.windowTitle,
      brand.aboutText,
      brand.legalLine,
      brand.copyright,
      brand.windowsCopyright,
      brand.fileDescription,
      brand.repositoryUrl,
      brand.repositoryLabel,
      brand.docsUrl,
      brand.releasesUrl,
      brand.wordmark,
      brand.greekWordmark,
      brand.footerMotto,
      brand.webTitle,
      brand.webDescription,
      brand.socialDescription,
      brand.manifestDescription,
      brand.appstreamSummary,
      brand.appstreamDescription,
      brand.developerName,
      brand.accentLabel,
      brand.packageTitle,
      brand.packageBlurb,
      welcomeTitle,
      aboutTitle,
      trayShow,
      trayTooltip('Connected'),
      loginSubtitle,
      chatWelcome,
      settingsAboutSubtitle,
      agentMonitorTitle,
      traySettingsHint,
      desktopRequiredBody,
      docsLinkDescription,
      voiceCompanionBody,
      hermesLocationHint,
      hermesDesktopDashboard('http://127.0.0.1:8642'),
      hubUnreachable('100.1.2.3'),
      testEmailSubject,
      startMenuHint,
      macDragHint,
      macLaunchHint,
      downloadTitle,
      downloadDescription,
      installBlurb,
      packageInstalling,
      minimizeHint,
      webProxyHint,
      porticoLine,
      urlProtocolLabel,
      pillarsLine,
      stoaLine,
      existsLine,
      cloudContinue,
      cloudConnectedTitle,
      cloudConnectedBody,
      installSh,
      installPs1,
      quarantineHint,
      brand.releaseAsset(brand.artifact('-Linux-1.0.0-x86_64.AppImage')),
    ];
  }
}
