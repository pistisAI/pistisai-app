import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:pistisai/services/hermes/hermes_local_agent_api.dart';

enum HermesBotInstallStatus { installed, skipped, failed }

class HermesBotInstallStep {
  final String name;
  final HermesBotInstallStatus status;
  final String detail;

  const HermesBotInstallStep({
    required this.name,
    required this.status,
    required this.detail,
  });
}

class HermesBotInstallReport {
  final List<HermesBotInstallStep> steps;

  const HermesBotInstallReport(this.steps);

  bool get succeeded =>
      steps.every((step) => step.status != HermesBotInstallStatus.failed);

  bool get hasFailures =>
      steps.any((step) => step.status == HermesBotInstallStatus.failed);

  HermesBotInstallStep? stepNamed(String name) {
    for (final step in steps) {
      if (step.name == name) {
        return step;
      }
    }
    return null;
  }
}

class HermesCommandResult {
  final int exitCode;
  final String stdout;
  final String stderr;

  const HermesCommandResult({
    required this.exitCode,
    this.stdout = '',
    this.stderr = '',
  });
}

typedef HermesCommandRunner = Future<HermesCommandResult> Function(
  List<String> args, {
  required String hermesHome,
});

typedef HermesAssetLoader = Future<List<int>> Function(String relativePath);

typedef HermesProcessHome = Future<String?> Function(int port);

/// Copies the pistisai package and aigent-watch profile into a Hermes home,
/// enables the plugin, and creates the drift-scan routine once.
///
/// The home is the Hermes the wizard connected to. A directory that merely
/// matches a Windows default install is not used in its place. [install]
/// never throws. A missing home or a missing `hermes` binary is a failed
/// step. Files whose bytes already match are left untouched, and a file that
/// differs is left in place so a local edit is not overwritten.
class HermesBotInstallService {
  HermesBotInstallService({
    String? Function()? readHome,
    HermesAssetLoader? loadAsset,
    HermesCommandRunner? runHermes,
    bool Function()? isWeb,
    HermesProcessHome? processHome,
  })  : _readHome = readHome,
        _loadAsset = loadAsset ?? _loadBundledAsset,
        _runHermes = runHermes ?? _runHermesProcess,
        _isWeb = isWeb ?? (() => kIsWeb),
        _processHome = processHome;

  static const agentStep = 'PistisAI package';
  static const desktopStep = 'Desktop embed';
  static const profileStep = 'aigent-watch profile';
  static const enableStep = 'Enable pistisai';
  static const routineStep = 'drift-scan routine';

  static const pluginName = 'pistisai';
  static const driftScanCronName = '[bot:aigent-watch] drift-scan';
  static const driftScanSchedule = 'every 6h';
  static const driftScanDeliver = 'origin';
  static const driftScanPrompt =
      'Run python "\$HERMES_HOME/profiles/aigent-watch/drift_scanner.py". '
      'If the JSON contains C3 or C4 findings, message the main agent with '
      'the file, line, and check. If there are no C3 or C4 findings, stay silent.';

  static const desktopSkipDetail =
      'Hermes Desktop cannot embed a page. view.showBrowser is a toggle '
      'and the plugin SDK has no webview.';

  static const List<String> agentFiles = <String>[
    'plugins/pistisai/plugin.yaml',
    'plugins/pistisai/__init__.py',
  ];

  static const List<String> profileFiles = <String>[
    'profiles/aigent-watch/SOUL.md',
    'profiles/aigent-watch/drift_scanner.py',
    'profiles/aigent-watch/skills/drift-scan/SKILL.md',
  ];

  final String? Function()? _readHome;
  final HermesAssetLoader _loadAsset;
  final HermesCommandRunner _runHermes;
  final bool Function() _isWeb;
  final HermesProcessHome? _processHome;

  Future<HermesBotInstallReport> install({int? agentPort}) async {
    try {
      if (_isWeb()) {
        return HermesBotInstallReport(<HermesBotInstallStep>[
          _skipped(agentStep, 'Skipped on web.'),
          _skipped(desktopStep, 'Skipped on web.'),
          _skipped(profileStep, 'Skipped on web.'),
          _skipped(enableStep, 'Skipped on web.'),
          _skipped(routineStep, 'Skipped on web.'),
        ]);
      }

      final home = (await _resolveHome(agentPort))?.trim();
      if (home == null || home.isEmpty) {
        return HermesBotInstallReport(<HermesBotInstallStep>[
          _failed(agentStep, 'Hermes home was not found.'),
          _skipped(desktopStep, desktopSkipDetail),
          _failed(profileStep, 'Hermes home was not found.'),
          _failed(enableStep, 'Hermes home was not found.'),
          _failed(routineStep, 'Hermes home was not found.'),
        ]);
      }

      final steps = <HermesBotInstallStep>[
        await _copyGroup(name: agentStep, files: agentFiles, home: home),
        _skipped(desktopStep, desktopSkipDetail),
        await _copyGroup(name: profileStep, files: profileFiles, home: home),
        await _enablePlugin(home),
        await _ensureRoutine(home),
      ];
      return HermesBotInstallReport(steps);
    } catch (error) {
      return HermesBotInstallReport(<HermesBotInstallStep>[
        _failed(agentStep, '$error'),
      ]);
    }
  }

  Future<String?> _resolveHome(int? agentPort) async {
    final override = _readHome;
    if (override != null) {
      return override();
    }
    if (agentPort != null && agentPort > 0) {
      final fromProcess = await (_processHome ?? listeningHermesHome)(agentPort);
      if (fromProcess != null && fromProcess.trim().isNotEmpty) {
        return fromProcess.trim();
      }
    }
    final explicit = Platform.environment['HERMES_HOME']?.trim();
    if (explicit != null && explicit.isNotEmpty) {
      return explicit;
    }
    return null;
  }

  Future<HermesBotInstallStep> _copyGroup({
    required String name,
    required List<String> files,
    required String home,
  }) async {
    var wrote = 0;
    final notes = <String>[];
    for (final relative in files) {
      try {
        final bytes = await _loadAsset(relative);
        final dest = File(_join(home, relative));
        if (await dest.exists()) {
          final existing = await dest.readAsBytes();
          if (_bytesEqual(existing, bytes)) {
            notes.add('$relative unchanged');
          } else {
            notes.add('$relative left in place');
          }
          continue;
        }
        await dest.parent.create(recursive: true);
        await dest.writeAsBytes(bytes, flush: true);
        wrote++;
      } catch (error) {
        return _failed(name, '$relative: $error');
      }
    }
    if (wrote > 0) {
      final detail = notes.isEmpty
          ? 'Wrote $wrote file(s).'
          : 'Wrote $wrote file(s). ${notes.join('; ')}';
      return HermesBotInstallStep(
        name: name,
        status: HermesBotInstallStatus.installed,
        detail: detail,
      );
    }
    return HermesBotInstallStep(
      name: name,
      status: HermesBotInstallStatus.skipped,
      detail: notes.join('; '),
    );
  }

  Future<HermesBotInstallStep> _enablePlugin(String home) async {
    try {
      final result = await _runHermes(
        <String>[
          'plugins',
          'enable',
          pluginName,
          '--no-allow-tool-override',
        ],
        hermesHome: home,
      );
      if (result.exitCode != 0) {
        return _failed(enableStep, _commandDetail(result));
      }
      return const HermesBotInstallStep(
        name: enableStep,
        status: HermesBotInstallStatus.installed,
        detail: 'hermes plugins enable pistisai --no-allow-tool-override',
      );
    } catch (error) {
      return _failed(enableStep, '$error');
    }
  }

  Future<HermesBotInstallStep> _ensureRoutine(String home) async {
    try {
      final listed = await _runHermes(
        <String>['cron', 'list'],
        hermesHome: home,
      );
      if (listed.exitCode != 0) {
        return _failed(routineStep, _commandDetail(listed));
      }
      if (listed.stdout.contains(driftScanCronName) ||
          listed.stderr.contains(driftScanCronName)) {
        return const HermesBotInstallStep(
          name: routineStep,
          status: HermesBotInstallStatus.skipped,
          detail: 'Routine already exists.',
        );
      }
      final created = await _runHermes(
        <String>[
          'cron',
          'create',
          '--name',
          driftScanCronName,
          '--deliver',
          driftScanDeliver,
          driftScanSchedule,
          driftScanPrompt,
        ],
        hermesHome: home,
      );
      if (created.exitCode != 0) {
        return _failed(routineStep, _commandDetail(created));
      }
      return const HermesBotInstallStep(
        name: routineStep,
        status: HermesBotInstallStatus.installed,
        detail: 'Created [bot:aigent-watch] drift-scan every 6h.',
      );
    } catch (error) {
      return _failed(routineStep, '$error');
    }
  }

  static HermesBotInstallStep _skipped(String name, String detail) {
    return HermesBotInstallStep(
      name: name,
      status: HermesBotInstallStatus.skipped,
      detail: detail,
    );
  }

  static HermesBotInstallStep _failed(String name, String detail) {
    return HermesBotInstallStep(
      name: name,
      status: HermesBotInstallStatus.failed,
      detail: detail,
    );
  }

  static String _commandDetail(HermesCommandResult result) {
    final text = '${result.stderr} ${result.stdout}'.trim();
    if (text.isEmpty) {
      return 'hermes exited ${result.exitCode}';
    }
    return text;
  }

  static String _join(String home, String relative) {
    final parts = relative.split('/');
    return <String>[home, ...parts].join(Platform.pathSeparator);
  }

  static bool _bytesEqual(List<int> left, List<int> right) {
    if (left.length != right.length) {
      return false;
    }
    for (var i = 0; i < left.length; i++) {
      if (left[i] != right[i]) {
        return false;
      }
    }
    return true;
  }

  static Future<List<int>> _loadBundledAsset(String relativePath) async {
    final data = await rootBundle.load('assets/pistisai/hermes/$relativePath');
    return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
  }

  static Future<HermesCommandResult> _runHermesProcess(
    List<String> args, {
    required String hermesHome,
  }) async {
    final executable = findHermesExecutable(hermesHome) ?? 'hermes';
    final result = await Process.run(
      executable,
      args,
      workingDirectory: hermesHome,
      environment: <String, String>{
        ...Platform.environment,
        'HERMES_HOME': hermesHome,
      },
    );
    return HermesCommandResult(
      exitCode: result.exitCode,
      stdout: result.stdout.toString(),
      stderr: result.stderr.toString(),
    );
  }
}

/// Home directory of a Hermes process, taken from its executable or command line.
///
/// Prefers the parent of a `hermes-agent` directory (Windows-style layouts).
/// Also accepts a path whose home *is* `.hermes` (typical macOS/Linux install
/// at `~/.hermes/bin/hermes`). Does not invent a home from a folder that merely
/// exists on disk.
String? hermesHomeFromProcessText(String text) {
  final windowsAgent = RegExp(
    r'([A-Za-z]:\\(?:[^\\\r\n"]+\\)*?)hermes-agent(?:\\|"|\s|$)',
  ).firstMatch(text);
  if (windowsAgent != null) {
    return _trimHome(windowsAgent.group(1));
  }
  final posixAgent = RegExp(
    r'((?:/[^/\s"]+)+)/hermes-agent(?:/|"|\s|$)',
  ).firstMatch(text);
  if (posixAgent != null) {
    return _trimHome(posixAgent.group(1));
  }
  final windowsDot = RegExp(
    r'([A-Za-z]:\\(?:[^\\\r\n"]+\\)*?\.hermes)(?:\\|"|\s|$)',
  ).firstMatch(text);
  if (windowsDot != null) {
    return _trimHome(windowsDot.group(1));
  }
  final posixDot = RegExp(
    r'((?:/[^/\s"]+)+/\.hermes)(?:/|"|\s|$)',
  ).firstMatch(text);
  return _trimHome(posixDot?.group(1));
}

String? _trimHome(String? raw) {
  if (raw == null) {
    return null;
  }
  var home = raw.trim();
  while (home.endsWith('\\') || home.endsWith('/')) {
    home = home.substring(0, home.length - 1);
  }
  if (home.isEmpty || home.endsWith(':')) {
    return null;
  }
  return home;
}

/// Home of the Hermes process listening on [port], or null when it cannot be seen.
Future<String?> listeningHermesHome(int port) async {
  try {
    if (Platform.isWindows) {
      final net = await Process.run('netstat', <String>['-ano', '-p', 'tcp']);
      final pid = listeningPidFromNetstat('${net.stdout}', port);
      if (pid == null) {
        return null;
      }
      final info = await Process.run(
        'powershell',
        <String>[
          '-NoProfile',
          '-Command',
          '\$p = Get-CimInstance Win32_Process -Filter "ProcessId=$pid"; '
              'Write-Output \$p.ExecutablePath; Write-Output \$p.CommandLine',
        ],
      );
      return hermesHomeFromProcessText('${info.stdout}\n${info.stderr}');
    }
    final net = await Process.run(
      'lsof',
      <String>['-nP', '-iTCP:$port', '-sTCP:LISTEN', '-Fn'],
    );
    final pid = _lsofPid('${net.stdout}');
    if (pid == null) {
      return null;
    }
    final info = await Process.run('ps', <String>['-p', pid, '-o', 'command=']);
    return hermesHomeFromProcessText('${info.stdout}');
  } catch (_) {
    return null;
  }
}

/// PID of the process listening on exactly [port] in `netstat -ano` output.
String? listeningPidFromNetstat(String netstat, int port) {
  final expected = '$port';
  for (final line in netstat.split(RegExp(r'\r?\n'))) {
    final trimmed = line.trim();
    if (!trimmed.toUpperCase().contains('LISTEN')) {
      continue;
    }
    final parts = trimmed.split(RegExp(r'\s+'));
    if (parts.length < 5) {
      continue;
    }
    final local = parts[1];
    final colon = local.lastIndexOf(':');
    if (colon < 0) {
      continue;
    }
    if (local.substring(colon + 1) != expected) {
      continue;
    }
    final pid = parts.last;
    if (int.tryParse(pid) == null) {
      continue;
    }
    return pid;
  }
  return null;
}

String? _lsofPid(String output) {
  for (final line in output.split(RegExp(r'\r?\n'))) {
    if (line.startsWith('p') && int.tryParse(line.substring(1)) != null) {
      return line.substring(1);
    }
  }
  return null;
}
