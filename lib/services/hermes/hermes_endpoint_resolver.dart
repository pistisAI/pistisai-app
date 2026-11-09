import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:pistisai/brand/brand_copy.dart';
import 'package:pistisai/config/app_config.dart';

/// What a local Hermes URL turned out to be.
enum HermesEndpointKind {
  /// OpenAI-compatible agent API (`/health` or `/v1/models`).
  agentApi,

  /// Hermes desktop `hermes serve` dashboard (`/api/health` only).
  desktopDashboard,

  /// Nothing answered the agent or dashboard probes.
  unreachable,
}

/// Outcome of looking for a local Hermes endpoint.
class HermesEndpointResolution {
  final String url;
  final HermesEndpointKind kind;
  final String message;

  const HermesEndpointResolution({
    required this.url,
    required this.kind,
    required this.message,
  });

  bool get isAgentApi => kind == HermesEndpointKind.agentApi;

  bool get isDesktopDashboard => kind == HermesEndpointKind.desktopDashboard;
}

/// Returns an HTTP status code, or null when the request fails.
typedef HermesHttpProbe = Future<int?> Function(Uri uri);

/// Returns listen ports for local `hermes serve` processes.
typedef HermesServePortLookup = Future<List<int>> Function();

/// Finds the Hermes agent API, falling back through the desktop serve port.
///
/// Probe order is the saved URL, then [AppConfig.defaultHermesUrl], then
/// Windows listen ports owned by `hermes serve`. `--port 0` on the command
/// line is not the bound port, so those sockets are read from the process.
/// A 200 response from `GET /` is ignored. Only `/health` or `/v1/models`
/// counts as the agent API.
class HermesEndpointResolver {
  HermesEndpointResolver({
    HermesHttpProbe? probe,
    HermesServePortLookup? listServePorts,
  })  : _probe = probe ?? probeHermesEndpoint,
        _listServePorts = listServePorts ?? discoverWindowsHermesServePorts;

  final HermesHttpProbe _probe;
  final HermesServePortLookup _listServePorts;

  /// Search saved, default, then live `hermes serve` ports.
  ///
  /// The first agent API wins. A desktop dashboard is returned only when no
  /// agent API answered. Otherwise the result is the default URL, unreachable.
  Future<HermesEndpointResolution> resolve({String? savedUrl}) async {
    final probed = <String>[];
    HermesEndpointResolution? dashboard;

    Future<HermesEndpointResolution?> probeCandidate(String? raw) async {
      final base = _normalizeBase(raw);
      if (base == null || probed.contains(base)) {
        return null;
      }
      probed.add(base);
      final result = await classify(base);
      if (result.isAgentApi) {
        return result;
      }
      if (dashboard == null && result.isDesktopDashboard) {
        dashboard = result;
      }
      return null;
    }

    final savedHit = await probeCandidate(savedUrl);
    if (savedHit != null) {
      return savedHit;
    }
    final defaultHit = await probeCandidate(AppConfig.defaultHermesUrl);
    if (defaultHit != null) {
      return defaultHit;
    }

    final ports = await _listServePorts();
    for (final port in ports) {
      if (port <= 0 || port > 65535) {
        continue;
      }
      final serveHit = await probeCandidate('http://127.0.0.1:$port');
      if (serveHit != null) {
        return serveHit;
      }
    }

    return dashboard ??
        HermesEndpointResolution(
          url: AppConfig.defaultHermesUrl,
          kind: HermesEndpointKind.unreachable,
          message: hermesUnreachableMessage,
        );
  }

  /// Classify one base URL. Does not scan other ports.
  Future<HermesEndpointResolution> classify(String url) async {
    final base = _normalizeBase(url) ?? AppConfig.defaultHermesUrl;

    final health = await _status(base, '/health');
    if (health == 200) {
      return HermesEndpointResolution(
        url: base,
        kind: HermesEndpointKind.agentApi,
        message: 'Connected successfully',
      );
    }

    final models = await _status(base, '/v1/models');
    if (models == 200) {
      return HermesEndpointResolution(
        url: base,
        kind: HermesEndpointKind.agentApi,
        message: 'Connected successfully',
      );
    }

    final dashboard = await _status(base, '/api/health');
    if (dashboard == 200) {
      return HermesEndpointResolution(
        url: base,
        kind: HermesEndpointKind.desktopDashboard,
        message: hermesDesktopDashboardMessage(base),
      );
    }

    return HermesEndpointResolution(
      url: base,
      kind: HermesEndpointKind.unreachable,
      message: hermesUnreachableMessage,
    );
  }

  Future<int?> _status(String base, String path) {
    return _probe(Uri.parse('$base$path'));
  }

  String? _normalizeBase(String? raw) {
    if (raw == null) {
      return null;
    }
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    final normalized = AppConfig.normalizeHermesUrl(trimmed);
    final uri = Uri.tryParse(normalized);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      return normalized.replaceAll(RegExp(r'/+$'), '');
    }
    // Build the origin by hand. Uri.replace(query: '', fragment: '') emits
    // "?#" and the following path is parsed as a fragment.
    final portSuffix = uri.hasPort ? ':${uri.port}' : '';
    return '${uri.scheme}://${uri.host}$portSuffix';
  }
}

/// Shown when the desktop dashboard is up and the agent API is not.
String hermesDesktopDashboardMessage(String url) =>
    BrandCopy.hermesDesktopDashboard(url);

/// Shown when no Hermes endpoint answered.
const String hermesUnreachableMessage =
    'Connection test failed. Verify your connection settings and try again.';

/// GET [uri] and return the status code, or null on failure.
Future<int?> probeHermesEndpoint(Uri uri) async {
  try {
    final response = await http.get(uri).timeout(const Duration(seconds: 3));
    return response.statusCode;
  } catch (_) {
    return null;
  }
}

/// Listen ports for Windows processes whose command line is `hermes serve`.
///
/// Returns an empty list on other platforms. The command line `--port 0` is
/// ignored; the bound socket is the port that matters.
Future<List<int>> discoverWindowsHermesServePorts() async {
  if (kIsWeb || !Platform.isWindows) {
    return const <int>[];
  }

  try {
    final result = await Process.run(
      'powershell',
      <String>[
        '-NoProfile',
        '-NonInteractive',
        '-Command',
        _windowsServePortScript,
      ],
      stdoutEncoding: const SystemEncoding(),
      stderrEncoding: const SystemEncoding(),
    ).timeout(const Duration(seconds: 8));

    final Object? stdout = result.stdout;
    if (result.exitCode != 0 || stdout is! String) {
      return const <int>[];
    }
    return parseHermesServePortLines(stdout);
  } catch (e) {
    debugPrint('[HermesEndpoint] Could not list hermes serve ports: $e');
    return const <int>[];
  }
}

/// Parse one port per line from the Windows serve-port lookup.
List<int> parseHermesServePortLines(String output) {
  final ports = <int>[];
  for (final line in output.split(RegExp(r'\r?\n'))) {
    final parsed = int.tryParse(line.trim());
    if (parsed == null || parsed <= 0 || parsed > 65535) {
      continue;
    }
    if (!ports.contains(parsed)) {
      ports.add(parsed);
    }
  }
  return ports;
}

const String _windowsServePortScript = r'''
$ids = @(Get-CimInstance Win32_Process | Where-Object {
  $cmd = $_.CommandLine
  if ([string]::IsNullOrWhiteSpace($cmd)) { return $false }
  $cmd = $cmd.ToLowerInvariant()
  $cmd.Contains('hermes') -and $cmd.Contains('serve')
} | Select-Object -ExpandProperty ProcessId)
$ports = New-Object System.Collections.Generic.List[int]
foreach ($procId in $ids) {
  $conns = Get-NetTCPConnection -OwningProcess $procId -State Listen -ErrorAction SilentlyContinue
  foreach ($conn in $conns) {
    $addr = [string]$conn.LocalAddress
    if ($addr -eq '127.0.0.1' -or $addr -eq '0.0.0.0' -or $addr -eq '::1' -or $addr -eq '::') {
      [void]$ports.Add([int]$conn.LocalPort)
    }
  }
}
$ports | Sort-Object -Unique | ForEach-Object { $_ }
''';
