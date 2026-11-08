import 'brand_config.dart';

/// Parse `brand/<id>/brand.yaml`.
///
/// The file is a small subset of YAML: scalar keys, one nested `colors` map,
/// and `|` block scalars. Quoted strings use single or double quotes.
BrandConfig parseBrandYaml(String source) {
  final scalars = <String, String>{};
  final colors = <String, String>{};
  String? blockKey;
  final block = StringBuffer();
  var inColors = false;

  void finishBlock() {
    if (blockKey == null) {
      return;
    }
    var text = block.toString();
    if (text.endsWith('\n')) {
      text = text.substring(0, text.length - 1);
    }
    scalars[blockKey!] = text;
    blockKey = null;
    block.clear();
  }

  for (final raw in source.split('\n')) {
    if (blockKey != null) {
      if (raw.startsWith('  ') || raw.trim().isEmpty) {
        block.writeln(raw.startsWith('  ') ? raw.substring(2) : '');
        continue;
      }
      finishBlock();
    }

    if (raw.trim().isEmpty || raw.trimLeft().startsWith('#')) {
      continue;
    }

    if (raw.startsWith('  ')) {
      if (!inColors) {
        throw FormatException('Unexpected nested YAML entry: $raw');
      }
      final nested = _splitKey(raw.trim());
      colors[nested.$1] = _unquote(nested.$2);
      continue;
    }

    final pair = _splitKey(raw.trim());
    if (pair.$1 == 'colors' && pair.$2.isEmpty) {
      inColors = true;
      continue;
    }
    inColors = false;
    if (pair.$2 == '|') {
      blockKey = pair.$1;
      continue;
    }
    scalars[pair.$1] = _unquote(pair.$2);
  }
  finishBlock();

  String req(String key) {
    final value = scalars[key];
    if (value == null || value.isEmpty) {
      throw FormatException('brand.yaml is missing $key');
    }
    return value;
  }

  String color(String key) {
    final value = colors[key];
    if (value == null || value.isEmpty) {
      throw FormatException('brand.yaml colors.$key is missing');
    }
    return value;
  }

  return BrandConfig(
    id: req('id'),
    productName: req('product_name'),
    shortName: req('short_name'),
    companyName: req('company_name'),
    tagline: req('tagline'),
    supportEmail: req('support_email'),
    supportUrl: req('support_url'),
    privacyEmail: req('privacy_email'),
    websiteDomain: req('website_domain'),
    websiteUrl: req('website_url'),
    appUrl: req('app_url'),
    defaultLocale: req('default_locale'),
    lockLocale: _parseBool(req('lock_locale'), 'lock_locale'),
    logoAsset: req('logo_asset'),
    iconAsset: req('icon_asset'),
    wordmark: req('wordmark'),
    greekWordmark: scalars['greek_wordmark'] ?? '',
    primaryArgb: _parseHex(color('primary')),
    secondaryArgb: _parseHex(color('secondary')),
    accentArgb: _parseHex(color('accent')),
    backgroundArgb: _parseHex(color('background')),
    textArgb: _parseHex(color('text')),
    appId: req('app_id'),
    bundleId: req('bundle_id'),
    linuxApplicationId: req('linux_application_id'),
    executableName: req('executable_name'),
    windowTitle: req('window_title'),
    aboutText: req('about_text'),
    closingLine: req('closing_line'),
    legalLine: req('legal_line'),
    copyright: req('copyright'),
    windowsCopyright: req('windows_copyright'),
    fileDescription: req('file_description'),
    repositoryUrl: req('repository_url'),
    repositoryLabel: req('repository_label'),
    docsUrl: req('docs_url'),
    releasesUrl: req('releases_url'),
    artifactPrefix: req('artifact_prefix'),
    accentLabel: req('accent_label'),
    packageTitle: req('package_title'),
    packageBlurb: req('package_blurb'),
    footerMotto: req('footer_motto'),
    webTitle: req('web_title'),
    webDescription: req('web_description'),
    socialDescription: req('social_description'),
    manifestDescription: req('manifest_description'),
    appstreamSummary: req('appstream_summary'),
    appstreamDescription: req('appstream_description'),
    developerName: req('developer_name'),
  );
}

(String, String) _splitKey(String line) {
  final index = line.indexOf(':');
  if (index <= 0) {
    throw FormatException('Invalid YAML line: $line');
  }
  return (line.substring(0, index).trim(), line.substring(index + 1).trim());
}

String _unquote(String value) {
  if (value.length >= 2) {
    final first = value[0];
    final last = value[value.length - 1];
    if ((first == '"' && last == '"') || (first == "'" && last == "'")) {
      return value.substring(1, value.length - 1);
    }
  }
  return value;
}

bool _parseBool(String value, String key) {
  if (value == 'true') {
    return true;
  }
  if (value == 'false') {
    return false;
  }
  throw FormatException('brand.yaml $key must be true or false');
}

int _parseHex(String value) {
  var hex = value.trim();
  if (hex.startsWith('#')) {
    hex = hex.substring(1);
  }
  if (hex.length == 6) {
    hex = 'FF$hex';
  }
  if (hex.length != 8) {
    throw FormatException('Color must be #RRGGBB: $value');
  }
  final parsed = int.tryParse(hex, radix: 16);
  if (parsed == null) {
    throw FormatException('Color must be #RRGGBB: $value');
  }
  return parsed;
}
