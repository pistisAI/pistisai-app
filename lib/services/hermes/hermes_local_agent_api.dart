import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:pistisai/services/hermes/hermes_endpoint_resolver.dart';

/// Result of making the local Hermes agent API reachable.
class HermesAgentApiReady {
  final HermesEndpointResolution resolution;
  final String? apiKey;

  const HermesAgentApiReady({
    required this.resolution,
    this.apiKey,
  });
}

/// Starts the Hermes gateway API server when only the desktop dashboard is up.
///
/// `hermes serve` is the desktop UI. Pistisai speaks the gateway API server
/// (`/health` and `/v1` on port 8642). That platform stays off until
/// `API_SERVER_KEY` is in the Hermes `.env` and the gateway is restarted.
class HermesLocalAgentApi {
  HermesLocalAgentApi({
    String? Function()? readHome,
    Future<bool> Function(String home)? restartGateway,
    String Function()? generateKey,
  })  : _readHome = readHome ?? hermesHomeDirectory,
        _restartGateway = restartGateway ?? restartHermesGateway,
        _generateKey = generateKey ?? generateHermesApiServerKey;

  final String? Function() _readHome;
  final Future<bool> Function(String home) _restartGateway;
  final String Function() _generateKey;

  /// Return an agent API resolution, starting the gateway API server if needed.
  Future<HermesAgentApiReady> ensure(
    HermesEndpointResolver resolver, {
    String? preferredKey,
  }) async {
    final current = await resolver.resolve();
    if (current.isAgentApi || kIsWeb) {
      return HermesAgentApiReady(resolution: current);
    }

    final home = _readHome();
    if (home == null || home.isEmpty) {
      return HermesAgentApiReady(resolution: current);
    }

    final key = writeHermesApiServerKey(
      home,
      preferredKey: preferredKey,
      generateKey: _generateKey,
    );
    debugPrint('[HermesAgentApi] API server key is set. Restarting gateway.');
    final restarted = await _restartGateway(home);
    if (!restarted) {
      debugPrint('[HermesAgentApi] Gateway restart did not succeed');
      return HermesAgentApiReady(resolution: current, apiKey: key);
    }

    var latest = current;
    for (var attempt = 0; attempt < 15; attempt++) {
      latest = await resolver.resolve();
      if (latest.isAgentApi) {
        return HermesAgentApiReady(resolution: latest, apiKey: key);
      }
      await Future<void>.delayed(const Duration(seconds: 1));
    }
    return HermesAgentApiReady(resolution: latest, apiKey: key);
  }
}

/// Hermes home directory, or null when this machine has no local install.
String? hermesHomeDirectory() {
  if (kIsWeb) {
    return null;
  }
  final fromEnv = Platform.environment['HERMES_HOME'];
  if (fromEnv != null && fromEnv.trim().isNotEmpty) {
    return fromEnv.trim();
  }
  final localAppData = Platform.environment['LOCALAPPDATA'];
  if (localAppData != null && localAppData.isNotEmpty) {
    final windowsHome = '$localAppData${Platform.pathSeparator}hermes';
    if (_looksLikeHermesHome(windowsHome)) {
      return windowsHome;
    }
  }
  final profile = Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'];
  if (profile != null && profile.isNotEmpty) {
    final unixHome = '$profile${Platform.pathSeparator}.hermes';
    if (_looksLikeHermesHome(unixHome)) {
      return unixHome;
    }
  }
  return null;
}

bool _looksLikeHermesHome(String path) {
  return File('$path${Platform.pathSeparator}.env').existsSync() ||
      File('$path${Platform.pathSeparator}config.yaml').existsSync() ||
      Directory('$path${Platform.pathSeparator}hermes-agent').existsSync();
}

/// Write a usable `API_SERVER_KEY` into [home]'s `.env` and return that key.
///
/// An existing key of at least 16 characters is kept. Hermes enables the API
/// server from that key on the next gateway start.
String writeHermesApiServerKey(
  String home, {
  String? preferredKey,
  String Function()? generateKey,
}) {
  final file = File('$home${Platform.pathSeparator}.env');
  final existing = file.existsSync() ? file.readAsStringSync() : '';
  final updated = upsertApiServerEnv(
    existing,
    preferredKey: preferredKey,
    generateKey: generateKey ?? generateHermesApiServerKey,
  );
  if (updated.changed || !file.existsSync()) {
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(updated.content);
  }
  return updated.key;
}

/// `.env` text after ensuring `API_SERVER_KEY` and `API_SERVER_ENABLED=true`.
({String content, String key, bool changed}) upsertApiServerEnv(
  String existing, {
  String? preferredKey,
  required String Function() generateKey,
}) {
  final newline = existing.contains('\r\n') ? '\r\n' : '\n';
  final lines = existing.split(RegExp(r'\r?\n'));
  final preferred = _usableKey(preferredKey);
  String? key;
  var keyIndex = -1;
  var enabledIndex = -1;

  for (var i = 0; i < lines.length; i++) {
    final trimmed = lines[i].trim();
    if (trimmed.startsWith('API_SERVER_KEY=')) {
      keyIndex = i;
      key = _usableKey(trimmed.substring('API_SERVER_KEY='.length));
    } else if (trimmed.startsWith('API_SERVER_ENABLED=')) {
      enabledIndex = i;
    }
  }

  var changed = false;
  final chosen = key ?? preferred ?? generateKey();
  if (keyIndex == -1) {
    if (lines.isNotEmpty && lines.last.trim().isEmpty) {
      lines.removeLast();
    }
    lines.add('API_SERVER_KEY=$chosen');
    changed = true;
  } else if (key == null) {
    lines[keyIndex] = 'API_SERVER_KEY=$chosen';
    changed = true;
  }

  if (enabledIndex == -1) {
    lines.add('API_SERVER_ENABLED=true');
    changed = true;
  } else if (lines[enabledIndex].trim() != 'API_SERVER_ENABLED=true') {
    lines[enabledIndex] = 'API_SERVER_ENABLED=true';
    changed = true;
  }

  var content = lines.join(newline);
  if (!content.endsWith(newline)) {
    content = '$content$newline';
    changed = true;
  }
  return (content: content, key: chosen, changed: changed);
}

String? _usableKey(String? raw) {
  if (raw == null) {
    return null;
  }
  var value = raw.trim();
  if (value.length >= 2 &&
      ((value.startsWith('"') && value.endsWith('"')) ||
          (value.startsWith("'") && value.endsWith("'")))) {
    value = value.substring(1, value.length - 1).trim();
  }
  if (value.length < 16) {
    return null;
  }
  return value;
}

/// 64 hex characters with a `psk_` prefix. Hermes requires at least 16.
String generateHermesApiServerKey() {
  final random = Random.secure();
  final values = List<int>.generate(32, (int i) => random.nextInt(256));
  return 'psk_${values.map((int v) => v.toRadixString(16).padLeft(2, '0')).join()}';
}

/// `hermes gateway restart` so a newly written API key is loaded.
Future<bool> restartHermesGateway(String home) async {
  final executable = findHermesExecutable(home);
  if (executable == null) {
    debugPrint('[HermesAgentApi] No hermes executable for $home');
    return false;
  }
  try {
    final env = Map<String, String>.from(Platform.environment);
    env['HERMES_HOME'] = home;
    final result = await Process.run(
      executable,
      const <String>['gateway', 'restart'],
      environment: env,
      workingDirectory: home,
      stdoutEncoding: const SystemEncoding(),
      stderrEncoding: const SystemEncoding(),
    ).timeout(const Duration(seconds: 90));
    debugPrint('[HermesAgentApi] gateway restart exit ${result.exitCode}');
    return result.exitCode == 0;
  } catch (e) {
    debugPrint('[HermesAgentApi] gateway restart failed: $e');
    return false;
  }
}

/// Launcher for the Hermes CLI next to [home], or `hermes` on PATH.
String? findHermesExecutable(String home) {
  final separator = Platform.pathSeparator;
  final candidates = <String>[
    '$home${separator}hermes-agent$separator.hermes${separator}bin${separator}hermes.exe',
    '$home${separator}hermes-agent$separator.hermes${separator}bin${separator}hermes.cmd',
    '$home${separator}hermes-agent$separator.hermes${separator}bin${separator}hermes',
    '$home${separator}bin${separator}hermes.exe',
    '$home${separator}bin${separator}hermes',
  ];
  for (final candidate in candidates) {
    if (File(candidate).existsSync()) {
      return candidate;
    }
  }
  return null;
}
