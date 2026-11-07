import '../services/enhanced_user_tier_service.dart';

/// Public Cloudflare Access settings. Compile-time `--dart-define` values
/// override the live account defaults. No secrets.
class CloudflareAccessConfig {
  static const String teamDomain = String.fromEnvironment(
    'CF_ACCESS_TEAM_DOMAIN',
    defaultValue: 'pistisai.cloudflareaccess.com',
  );

  static const String issuer = String.fromEnvironment(
    'CF_ACCESS_ISSUER',
    defaultValue: 'https://pistisai.cloudflareaccess.com',
  );

  static const String jwksUrl = String.fromEnvironment(
    'CF_ACCESS_JWKS_URL',
    defaultValue: 'https://pistisai.cloudflareaccess.com/cdn-cgi/access/certs',
  );

  /// Host the desktop tunnel and sync client calls.
  static const String tunnelHost = String.fromEnvironment(
    'CF_ACCESS_TUNNEL_HOST',
    defaultValue: 'api.pistisai.app',
  );

  /// AUD tag for [tunnelHost].
  static const String audience = String.fromEnvironment(
    'CF_ACCESS_AUD',
    defaultValue:
        'c0134585f8067b43908572f93046917aedfb9b8d111f3ed716e3fc204e8fe7d3',
  );

  /// Web app host. Not the tunnel audience.
  static const String appHost = 'app.pistisai.app';

  static const String appAudience =
      'b1f78e752af5c24fccb62238333da87fca981436711244f31ba6d612b92bc9fd';

  static Uri loginUri({String? redirectUrl}) {
    final uri = Uri.parse(
      'https://$teamDomain/cdn-cgi/access/login/$audience',
    );
    if (redirectUrl == null || redirectUrl.isEmpty) return uri;
    return uri.replace(queryParameters: {'redirect_url': redirectUrl});
  }
}

/// Free tier uses the pistisai.app tunnel. Paid plans use the customer's
/// own Tailscale or VPN and never contact Cloudflare Access.
bool tierUsesCustomerNetwork(UserTier tier) {
  switch (tier) {
    case UserTier.free:
      return false;
    case UserTier.premium:
    case UserTier.business:
    case UserTier.enterprise:
      return true;
  }
}
