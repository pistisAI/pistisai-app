import 'dart:io';

import 'package:hooks/hooks.dart';

/// Pub tarball for the cnativeapi revision this repo builds from.
const _cnativeapiArchive =
    'https://pub.dev/api/archives/cnativeapi-0.5.2.tar.gz';

const _aptPackages = [
  'clang',
  'cmake',
  'ninja-build',
  'pkg-config',
  'libgtk-3-dev',
  'libx11-dev',
  'libxi-dev',
  'liblzma-dev',
  'libstdc++-12-dev',
];

void main(List<String> args) async {
  await build(args, (input, output) async {
    if (!Platform.isLinux) return;
    if (!await _pkgConfigOk()) {
      await _aptInstall();
    }
    await _ensureCxxImpl(input.packageRoot);
  });
}

Future<bool> _pkgConfigOk() async {
  final result = await Process.run('pkg-config', [
    '--exists',
    'gtk+-3.0',
    'x11',
    'xi',
  ]);
  return result.exitCode == 0;
}

/// Ubuntu CI runners have passwordless sudo and no GTK/X11/Xi headers.
/// Machines without apt (or without passwordless sudo) are left unchanged;
/// the cnativeapi hook then reports the missing packages itself.
Future<void> _aptInstall() async {
  if (!await _commandOk('apt-get')) return;
  final sudo = await Process.run('sudo', ['-n', 'true']);
  if (sudo.exitCode != 0) return;

  final update = await Process.run('sudo', ['-n', 'apt-get', 'update', '-qq']);
  if (update.exitCode != 0) {
    throw StateError('apt-get update failed:\n${update.stderr}');
  }
  final install = await Process.run('sudo', [
    '-n',
    'apt-get',
    'install',
    '-y',
    '-qq',
    ..._aptPackages,
  ]);
  if (install.exitCode != 0) {
    throw StateError('apt-get install failed:\n${install.stderr}');
  }
}

void _copyDirectory(Directory from, Directory to) {
  to.createSync(recursive: true);
  for (final entity in from.listSync(followLinks: false)) {
    final name = entity.path.split(Platform.pathSeparator).last;
    if (entity is Directory) {
      _copyDirectory(
        entity,
        Directory('${to.path}${Platform.pathSeparator}$name'),
      );
    } else if (entity is File) {
      entity.copySync('${to.path}${Platform.pathSeparator}$name');
    }
  }
}

Future<bool> _commandOk(String name) async {
  final result = await Process.run('bash', ['-lc', 'command -v $name']);
  return result.exitCode == 0 && (result.stdout as String).trim().isNotEmpty;
}

Future<void> _ensureCxxImpl(Uri packageRoot) async {
  final dest = Directory.fromUri(
    packageRoot.resolve('../cnativeapi/cxx_impl/'),
  );
  final marker = File('${dest.path}/src/CMakeLists.txt');
  if (marker.existsSync()) return;

  final tmp = await Directory.systemTemp.createTemp('cnativeapi-src-');
  try {
    final archive = File('${tmp.path}/cnativeapi.tar.gz');
    final client = HttpClient();
    try {
      final request = await client.getUrl(Uri.parse(_cnativeapiArchive));
      final response = await request.close();
      if (response.statusCode != 200) {
        throw StateError(
          'Failed to download cnativeapi sources '
          '(${response.statusCode}) from $_cnativeapiArchive',
        );
      }
      await response.pipe(archive.openWrite());
    } finally {
      client.close(force: true);
    }

    final extract = await Process.run('tar', [
      '-xzf',
      archive.path,
      '-C',
      tmp.path,
      'cxx_impl',
    ]);
    if (extract.exitCode != 0) {
      throw StateError('tar extract failed:\n${extract.stderr}');
    }
    final extracted = Directory('${tmp.path}/cxx_impl');
    if (!extracted.existsSync()) {
      throw StateError('cnativeapi archive did not contain cxx_impl/');
    }
    if (dest.existsSync()) dest.deleteSync(recursive: true);
    _copyDirectory(extracted, dest);
  } finally {
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  }
}
