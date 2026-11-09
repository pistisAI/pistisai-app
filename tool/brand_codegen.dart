import 'dart:io';

import 'package:pistisai/brand/brand_licence.dart';
import 'package:pistisai/brand/brand_yaml.dart';

import 'brand_emit.dart';

/// Bake `brand/<id>/brand.yaml` into the Flutter app and native metadata.
///
/// The upstream brand (`pistisai`) bakes freely. Any other brand is a paid
/// whitelabel and requires a valid licence, supplied either as a path or as
/// the licence JSON itself via `--license <path|json>`:
///
///   tool/brand.sh iacle --license /path/to/iacle.licence
///
/// Without a valid, unexpired licence for that brand the bake refuses to run.
Future<void> main(List<String> args) async {
  if (args.isEmpty || args.first.startsWith('-')) {
    stderr.writeln('Usage: tool/brand.sh <brand-id> [--license <path|json>]');
    exit(64);
  }
  final id = args.first;

  String? licenseSource;
  for (var i = 1; i < args.length; i++) {
    if (args[i] == '--license' && i + 1 < args.length) {
      licenseSource = args[i + 1];
      i++;
    }
  }

  final root = Directory.current.path;
  final yamlFile = File('$root/brand/$id/brand.yaml');
  if (!yamlFile.existsSync()) {
    stderr.writeln('No brand file at ${yamlFile.path}');
    exit(1);
  }
  final brand = parseBrandYaml(yamlFile.readAsStringSync());
  if (brand.id != id) {
    stderr.writeln('brand.yaml id "${brand.id}" does not match "$id"');
    exit(1);
  }

  // The upstream product is free. Every other brand is a licensed whitelabel.
  if (id != 'pistisai') {
    if (licenseSource == null || licenseSource.trim().isEmpty) {
      stderr.writeln(
        'Brand "$id" is a paid whitelabel. Supply a licence:\n'
        '  tool/brand.sh $id --license /path/to/$id.licence',
      );
      exit(66); // EX_NOINPUT — licence required
    }

    final licenceJson = await _readLicence(licenseSource);
    final result = await BrandLicence.validateJson(
      licenceJson,
      requestedBrand: id,
    );
    if (!result.isActive) {
      stderr.writeln('Licence rejected for brand "$id": ${result.displayStatus}');
      if (result.detail != null) {
        stderr.writeln('  ${result.detail}');
      }
      exit(65); // EX_DATAERR — licence invalid
    }
    stdout.writeln('Licence accepted: ${result.displayStatus}');
  }

  writeBrand(root, brand);
  stdout.writeln('Baked brand ${brand.id} (${brand.productName}).');
  stdout.writeln(
    'Build with: flutter build <target> --dart-define=BRAND=${brand.id}',
  );
}

/// Read a licence from a file path, or treat the argument as the JSON itself.
Future<String> _readLicence(String source) async {
  final trimmed = source.trim();
  final file = File(trimmed);
  if (file.existsSync()) {
    return file.readAsStringSync();
  }
  // Not a path — assume the argument is the licence JSON inline.
  return trimmed;
}
