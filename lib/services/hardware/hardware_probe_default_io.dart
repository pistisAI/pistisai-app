import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'hardware_probe.dart';

/// Probe wired to this computer: `Process.start` with argument lists only
/// (no shell), each command killed when it outlives its timeout.
PlatformHardwareProbe? createDefaultHardwareProbe() {
  return PlatformHardwareProbe(
    operatingSystem: Platform.operatingSystem,
    runCommand: _runCommand,
    readFile: _readFile,
    environment: Platform.environment,
  );
}

Future<ProbeCommandOutput?> _runCommand(
  String executable,
  List<String> arguments,
  Duration timeout,
) async {
  Process process;
  try {
    process = await Process.start(executable, arguments);
  } catch (_) {
    // Missing tool (for example no nvidia-smi): not an error for the check.
    return null;
  }
  // Nothing is written to the child; close stdin so it cannot wait on it.
  unawaited(process.stdin.close().catchError((Object _) {}));
  final stdoutFuture = process.stdout.transform(systemEncoding.decoder).join();
  unawaited(process.stderr.drain<void>().catchError((Object _) {}));
  try {
    final exitCode = await process.exitCode.timeout(timeout);
    final stdout = await stdoutFuture.timeout(timeout);
    return ProbeCommandOutput(exitCode: exitCode, stdout: stdout);
  } catch (_) {
    process.kill();
    return null;
  }
}

Future<String?> _readFile(String path) async {
  try {
    return await File(path)
        .readAsString(encoding: const Utf8Codec(allowMalformed: true));
  } catch (_) {
    return null;
  }
}
