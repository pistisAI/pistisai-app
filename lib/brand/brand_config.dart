/// One reseller (or the upstream product) as the app should present it.
///
/// Internal package names, hub paths, and API hostnames are not fields here.
/// Those stay in code. See `docs/WHITE_LABEL.md`.
class BrandConfig {
  const BrandConfig({
    required this.id,
    required this.productName,
    required this.shortName,
    required this.companyName,
    required this.tagline,
    required this.supportEmail,
    required this.supportUrl,
    required this.privacyEmail,
    required this.websiteDomain,
    required this.websiteUrl,
    required this.appUrl,
    required this.defaultLocale,
    required this.lockLocale,
    required this.logoAsset,
    required this.iconAsset,
    required this.wordmark,
    required this.greekWordmark,
    required this.primaryArgb,
    required this.secondaryArgb,
    required this.accentArgb,
    required this.backgroundArgb,
    required this.textArgb,
    required this.appId,
    required this.bundleId,
    required this.linuxApplicationId,
    required this.executableName,
    required this.windowTitle,
    required this.aboutText,
    required this.closingLine,
    required this.legalLine,
    required this.copyright,
    required this.windowsCopyright,
    required this.fileDescription,
    required this.repositoryUrl,
    required this.repositoryLabel,
    required this.docsUrl,
    required this.releasesUrl,
    required this.artifactPrefix,
    required this.accentLabel,
    required this.packageTitle,
    required this.packageBlurb,
    required this.footerMotto,
    required this.webTitle,
    required this.webDescription,
    required this.socialDescription,
    required this.manifestDescription,
    required this.appstreamSummary,
    required this.appstreamDescription,
    required this.developerName,
  });

  final String id;
  final String productName;
  final String shortName;
  final String companyName;
  final String tagline;
  final String supportEmail;
  final String supportUrl;
  final String privacyEmail;
  final String websiteDomain;
  final String websiteUrl;
  final String appUrl;
  final String defaultLocale;
  final bool lockLocale;
  final String logoAsset;
  final String iconAsset;
  final String wordmark;
  final String greekWordmark;
  final int primaryArgb;
  final int secondaryArgb;
  final int accentArgb;
  final int backgroundArgb;
  final int textArgb;
  final String appId;
  final String bundleId;
  final String linuxApplicationId;

  /// Recorded for installers and download labels. The Flutter binary name is
  /// not renamed from this value yet.
  final String executableName;
  final String windowTitle;
  final String aboutText;
  final String closingLine;
  final String legalLine;
  final String copyright;
  final String windowsCopyright;
  final String fileDescription;
  final String repositoryUrl;
  final String repositoryLabel;
  final String docsUrl;
  final String releasesUrl;
  final String artifactPrefix;
  final String accentLabel;
  final String packageTitle;
  final String packageBlurb;
  final String footerMotto;
  final String webTitle;
  final String webDescription;
  final String socialDescription;
  final String manifestDescription;
  final String appstreamSummary;
  final String appstreamDescription;
  final String developerName;

  /// `#rrggbb` lowercase, matching the committed web files for the default brand.
  String get backgroundHex =>
      '#${(backgroundArgb & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';

  String releaseAsset(String fileName) => '$releasesUrl/download/$fileName';

  String artifact(String suffix) => '$artifactPrefix$suffix';

  bool containsUpstreamProductName(String value) {
    final lower = value.toLowerCase();
    return lower.contains('pistisai');
  }
}
