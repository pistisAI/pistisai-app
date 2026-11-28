import 'hardware_parsers.dart';
import 'local_model_capability.dart';

/// Output of one command the probe ran.
class ProbeCommandOutput {
  const ProbeCommandOutput({required this.exitCode, required this.stdout});

  final int exitCode;
  final String stdout;
}

/// Runs [executable] with [arguments] (an argument list, never a shell
/// string) and returns its output, or null when it is missing, fails to
/// start, or does not finish within [timeout].
typedef ProbeCommandRunner = Future<ProbeCommandOutput?> Function(
  String executable,
  List<String> arguments,
  Duration timeout,
);

/// Reads a local text file, or returns null when it cannot be read.
typedef ProbeFileReader = Future<String?> Function(String path);

/// Reads hardware signals from this computer (#1077).
///
/// Everything platform-specific is injected, so tests feed recorded outputs
/// and never touch the real machine. Each probe is time-bound and any error
/// leaves its field null; [read] never throws. Nothing is installed and no
/// network call is made.
class PlatformHardwareProbe {
  PlatformHardwareProbe({
    required this.operatingSystem,
    required ProbeCommandRunner runCommand,
    required ProbeFileReader readFile,
    Map<String, String> environment = const {},
    this.probeTimeout = defaultProbeTimeout,
  })  : _run = runCommand,
        _readFile = readFile,
        _environment = environment;

  static const Duration defaultProbeTimeout = Duration(seconds: 3);

  /// Fixed PowerShell script: total bytes on line 1, free KiB on line 2.
  static const String windowsMemoryScript =
      '(Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory; '
      '(Get-CimInstance Win32_OperatingSystem).FreePhysicalMemory';

  static const List<String> nvidiaSmiArguments = [
    '--query-gpu=name,memory.total',
    '--format=csv,noheader,nounits',
  ];

  /// As reported by `Platform.operatingSystem` (`linux`, `macos`, `windows`).
  final String operatingSystem;
  final Duration probeTimeout;
  final ProbeCommandRunner _run;
  final ProbeFileReader _readFile;
  final Map<String, String> _environment;

  /// True when this probe knows how to read [operatingSystem].
  bool get isSupported =>
      const {'linux', 'macos', 'windows'}.contains(operatingSystem);

  /// Reads the snapshot, or returns null when the platform is not supported.
  Future<HardwareSnapshot?> read() async {
    switch (operatingSystem) {
      case 'linux':
        return _readLinux();
      case 'macos':
        return _readMac();
      case 'windows':
        return _readWindows();
      default:
        return null;
    }
  }

  Future<String?> _stdout(String executable, List<String> arguments) async {
    try {
      final output =
          await _run(executable, arguments, probeTimeout).timeout(probeTimeout);
      if (output == null || output.exitCode != 0) return null;
      return output.stdout;
    } catch (_) {
      return null;
    }
  }

  Future<String?> _file(String path) async {
    try {
      return await _readFile(path).timeout(probeTimeout);
    } catch (_) {
      return null;
    }
  }

  Future<({String? name, int? memoryBytes})> _nvidia() async {
    final out = await _stdout('nvidia-smi', nvidiaSmiArguments);
    if (out == null) return (name: null, memoryBytes: null);
    return parseNvidiaSmi(out);
  }

  Future<HardwareSnapshot> _readLinux() async {
    final results = await Future.wait<Object?>([
      _file('/proc/meminfo'),
      _stdout('uname', const ['-m']),
      _nvidia(),
    ]);
    final meminfo = results[0] as String?;
    final memory = meminfo == null
        ? (total: null, available: null)
        : parseLinuxMeminfo(meminfo);
    final gpu = results[2] as ({String? name, int? memoryBytes});
    return HardwareSnapshot(
      architecture: normalizeArchitecture(results[1] as String?),
      totalMemoryBytes: memory.total,
      availableMemoryBytes: memory.available,
      gpuName: gpu.name,
      gpuMemoryBytes: gpu.memoryBytes,
    );
  }

  Future<HardwareSnapshot> _readMac() async {
    final results = await Future.wait<String?>([
      _stdout('sysctl', const ['-n', 'hw.memsize']),
      _stdout('uname', const ['-m']),
      _stdout('vm_stat', const []),
    ]);
    return HardwareSnapshot(
      architecture: normalizeArchitecture(results[1]),
      totalMemoryBytes:
          results[0] == null ? null : parseSingleInteger(results[0]!),
      availableMemoryBytes:
          results[2] == null ? null : parseMacVmStatAvailable(results[2]!),
    );
  }

  Future<HardwareSnapshot> _readWindows() async {
    final results = await Future.wait<Object?>([
      _stdout('powershell', const [
        '-NoProfile',
        '-NonInteractive',
        '-Command',
        windowsMemoryScript,
      ]),
      _nvidia(),
    ]);
    final cim = results[0] as String?;
    var memory = cim == null
        ? (total: null, available: null)
        : parseWindowsCimMemory(cim);
    if (memory.total == null) {
      final wmic = await _stdout('wmic', const [
        'ComputerSystem',
        'get',
        'TotalPhysicalMemory',
        '/value',
      ]);
      if (wmic != null) {
        memory = (total: parseWmicTotalMemory(wmic), available: null);
      }
    }
    final gpu = results[1] as ({String? name, int? memoryBytes});
    // PROCESSOR_ARCHITEW6432 is set for 32-bit processes on 64-bit Windows.
    final arch = _environment['PROCESSOR_ARCHITEW6432'] ??
        _environment['PROCESSOR_ARCHITECTURE'];
    return HardwareSnapshot(
      architecture: normalizeArchitecture(arch),
      totalMemoryBytes: memory.total,
      availableMemoryBytes: memory.available,
      gpuName: gpu.name,
      gpuMemoryBytes: gpu.memoryBytes,
    );
  }
}
