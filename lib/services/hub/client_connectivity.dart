import 'package:pistisai/config/app_config.dart';

/// Where this Pistisai install sits relative to the primary desktop hub.
///
/// Only [ClientInstallRole.primaryHub] may open the co-resident Hermes
/// gateway (`127.0.0.1:8642`). Web, mobile, and a secondary desktop join
/// that hub on the router port and never dial the gateway themselves.
enum ClientInstallRole {
  primaryHub('primary_hub'),
  secondaryDesktop('secondary_desktop'),
  web('web'),
  mobile('mobile');

  final String storageValue;

  const ClientInstallRole(this.storageValue);

  static ClientInstallRole? parse(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    for (final role in ClientInstallRole.values) {
      if (role.storageValue == raw || role.name == raw) return role;
    }
    return null;
  }
}

/// Shown when a non-primary install is pointed at a Hermes gateway.
const String directHermesRefusal =
    'This install reaches Hermes only through the primary Pistisai desktop hub.';

/// True only for the desktop that is co-resident with Hermes.
bool allowsDirectHermesGateway(ClientInstallRole role) {
  return role == ClientInstallRole.primaryHub;
}

bool isLoopbackHost(String host) {
  switch (host.trim().toLowerCase()) {
    case '127.0.0.1':
    case 'localhost':
    case '::1':
      return true;
    default:
      return false;
  }
}

/// `http://host:1337` with any path stripped. Null when [url] is not a hub.
String? normalizeHubBaseUrl(String url) {
  final uri = _parse(url);
  if (uri == null || !uri.hasPort) return null;
  if (uri.port != AppConfig.defaultRouterPort) return null;
  return _origin(uri);
}

/// True when [url] targets the desktop router, not the Hermes gateway.
bool isHubBaseUrl(String url) {
  return normalizeHubBaseUrl(url) != null;
}

/// True when [url] is the Hermes gateway port (default 8642).
///
/// A hub URL is never a direct gateway URL. Loopback HTTP with no port is
/// treated as the default gateway, matching [AppConfig.normalizeHermesUrl].
bool isDirectHermesGatewayUrl(String url) {
  final uri = _parse(url);
  if (uri == null) return false;
  if (isHubBaseUrl(url)) return false;
  if (uri.hasPort && uri.port == AppConfig.defaultHermesPort) return true;
  return !uri.hasPort && uri.scheme == 'http' && isLoopbackHost(uri.host);
}

/// Same host as a Hermes gateway URL, on the hub router port.
///
/// Returns null for loopback. A phone or browser must not silently retarget
/// `127.0.0.1:8642` at its own router. Remote `host:8642` becomes `host:1337`.
String? hubBaseUrlForHermesGateway(String url) {
  final uri = _parse(url);
  if (uri == null) return null;
  if (isHubBaseUrl(url)) return normalizeHubBaseUrl(url);
  if (!isDirectHermesGatewayUrl(url)) return null;
  if (isLoopbackHost(uri.host)) return null;
  return _origin(uri.replace(port: AppConfig.defaultRouterPort));
}

/// A primary desktop that is given a remote hub or gateway URL is joining
/// that hub, not opening its own Hermes client.
ClientInstallRole roleForConfiguredUrl({
  required ClientInstallRole detected,
  required String url,
}) {
  if (detected != ClientInstallRole.primaryHub) return detected;
  final uri = _parse(url);
  if (uri == null || isLoopbackHost(uri.host)) return detected;
  if (isHubBaseUrl(url) || isDirectHermesGatewayUrl(url)) {
    return ClientInstallRole.secondaryDesktop;
  }
  return detected;
}

/// Where chat send/sync should go for [role].
class ChatTransportDecision {
  final bool allowed;
  final String? baseUrl;
  final String? refusal;

  /// True when [baseUrl] is the primary desktop hub, not the Hermes gateway.
  final bool viaHub;

  const ChatTransportDecision({
    required this.allowed,
    required this.baseUrl,
    required this.refusal,
    required this.viaHub,
  });
}

ChatTransportDecision resolveChatTransport({
  required ClientInstallRole role,
  String? configuredUrl,
  String? hubUrl,
}) {
  if (allowsDirectHermesGateway(role)) {
    final raw = configuredUrl?.trim();
    final url = AppConfig.normalizeHermesUrl(
      (raw == null || raw.isEmpty) ? AppConfig.defaultHermesUrl : raw,
    );
    return ChatTransportDecision(
      allowed: true,
      baseUrl: url,
      refusal: null,
      viaHub: false,
    );
  }

  final explicitHub = _clean(hubUrl);
  if (explicitHub != null && isHubBaseUrl(explicitHub)) {
    return ChatTransportDecision(
      allowed: true,
      baseUrl: normalizeHubBaseUrl(explicitHub),
      refusal: null,
      viaHub: true,
    );
  }

  final configured = _clean(configuredUrl);
  if (configured != null && isHubBaseUrl(configured)) {
    return ChatTransportDecision(
      allowed: true,
      baseUrl: normalizeHubBaseUrl(configured),
      refusal: null,
      viaHub: true,
    );
  }

  if (configured != null) {
    final joined = hubBaseUrlForHermesGateway(configured);
    if (joined != null) {
      return ChatTransportDecision(
        allowed: true,
        baseUrl: joined,
        refusal: null,
        viaHub: true,
      );
    }
  }

  return const ChatTransportDecision(
    allowed: false,
    baseUrl: null,
    refusal: directHermesRefusal,
    viaHub: false,
  );
}

/// Role for this process before a saved override is applied.
ClientInstallRole resolveClientInstallRole({
  required bool isWeb,
  required bool isMobile,
  String? storedRole,
  String? hubUrl,
  String? hermesUrl,
}) {
  final stored = ClientInstallRole.parse(storedRole);
  if (stored != null) return stored;
  if (isWeb) return ClientInstallRole.web;
  if (isMobile) return ClientInstallRole.mobile;
  final hub = _clean(hubUrl);
  if (hub != null && isHubBaseUrl(hub) && !isLoopbackHost(_parse(hub)!.host)) {
    return ClientInstallRole.secondaryDesktop;
  }
  final hermes = _clean(hermesUrl);
  if (hermes != null &&
      isDirectHermesGatewayUrl(hermes) &&
      !isLoopbackHost(_parse(hermes)!.host)) {
    return ClientInstallRole.secondaryDesktop;
  }
  return ClientInstallRole.primaryHub;
}

Uri? _parse(String url) {
  final trimmed = url.trim();
  if (trimmed.isEmpty) return null;
  final uri = Uri.tryParse(trimmed);
  if (uri == null || !uri.hasScheme || uri.host.isEmpty) return null;
  if (uri.scheme != 'http' && uri.scheme != 'https') return null;
  return uri;
}

String? _clean(String? url) {
  if (url == null) return null;
  final trimmed = url.trim();
  return trimmed.isEmpty ? null : trimmed;
}

String _origin(Uri uri) {
  final host = uri.host.contains(':') ? '[${uri.host}]' : uri.host;
  final portSuffix = uri.hasPort ? ':${uri.port}' : '';
  return '${uri.scheme}://$host$portSuffix';
}
