import 'dart:io';

import 'package:pistisai/brand/brand_yaml.dart';

import 'brand_emit.dart';

/// Bake `brand/<id>/brand.yaml` into the Flutter app and native metadata.
void main(List<String> args) {
  if (args.length != 1 || args.single.startsWith('-')) {
    stderr.writeln('Usage: tool/brand.sh <brand-id>');
    exit(64);
  }
  final id = args.single;
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
  writeBrand(root, brand);
  stdout.writeln('Baked brand ${brand.id} (${brand.productName}).');
  stdout.writeln(
    'Build with: flutter build <target> --dart-define=BRAND=${brand.id}',
  );
}
