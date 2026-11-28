/// Pure parsers for the outputs the hardware probe reads (#1077).
///
/// Each parser returns null when the text does not contain the value, so a
/// surprising output degrades to `unknown` instead of throwing.
library;

final RegExp _whitespace = RegExp(r'\s+');

/// Normalises an architecture name (`uname -m`, `PROCESSOR_ARCHITECTURE`).
String? normalizeArchitecture(String? raw) {
  final value = raw?.trim().toLowerCase();
  if (value == null || value.isEmpty) return null;
  return value.split(_whitespace).first;
}

/// Linux `/proc/meminfo`: returns `(total, available)` in bytes.
///
/// `MemAvailable` exists since kernel 3.14; older kernels fall back to
/// `MemFree`.
({int? total, int? available}) parseLinuxMeminfo(String text) {
  int? readKiB(String key) {
    final match =
        RegExp('^$key:\\s+(\\d+)\\s*kB', multiLine: true).firstMatch(text);
    if (match == null) return null;
    final kib = int.tryParse(match.group(1)!);
    return kib == null ? null : kib * 1024;
  }

  return (
    total: readKiB('MemTotal'),
    available: readKiB('MemAvailable') ?? readKiB('MemFree'),
  );
}

/// A single integer on the first non-empty line, e.g. `sysctl -n hw.memsize`.
int? parseSingleInteger(String text) {
  for (final line in text.split('\n')) {
    final trimmed = line.trim();
    if (trimmed.isEmpty) continue;
    return int.tryParse(trimmed);
  }
  return null;
}

/// macOS `vm_stat`: free plus inactive pages, in bytes.
int? parseMacVmStatAvailable(String text) {
  final pageSize = int.tryParse(
    RegExp(r'page size of (\d+) bytes').firstMatch(text)?.group(1) ?? '',
  );
  if (pageSize == null) return null;
  int? pages(String label) => int.tryParse(
        RegExp('^$label:\\s+(\\d+)', multiLine: true)
                .firstMatch(text)
                ?.group(1) ??
            '',
      );
  final free = pages('Pages free');
  if (free == null) return null;
  final inactive = pages('Pages inactive') ?? 0;
  final speculative = pages('Pages speculative') ?? 0;
  return (free + inactive + speculative) * pageSize;
}

/// PowerShell probe output: line 1 total bytes (`Win32_ComputerSystem
/// .TotalPhysicalMemory`), line 2 free KiB (`Win32_OperatingSystem
/// .FreePhysicalMemory`).
({int? total, int? available}) parseWindowsCimMemory(String text) {
  final lines =
      text.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
  final total = lines.isNotEmpty ? int.tryParse(lines[0]) : null;
  final freeKiB = lines.length > 1 ? int.tryParse(lines[1]) : null;
  return (total: total, available: freeKiB == null ? null : freeKiB * 1024);
}

/// `wmic ComputerSystem get TotalPhysicalMemory /value` output.
int? parseWmicTotalMemory(String text) {
  final match = RegExp(r'TotalPhysicalMemory=(\d+)').firstMatch(text);
  return match == null ? null : int.tryParse(match.group(1)!);
}

/// `nvidia-smi --query-gpu=name,memory.total --format=csv,noheader,nounits`.
///
/// Returns the GPU with the most memory. `memory.total` is in MiB.
({String? name, int? memoryBytes}) parseNvidiaSmi(String text) {
  String? bestName;
  int? bestBytes;
  for (final line in text.split('\n')) {
    final parts = line.split(',');
    if (parts.length < 2) continue;
    final mib = int.tryParse(parts.last.trim());
    if (mib == null) continue;
    final bytes = mib * 1024 * 1024;
    if (bestBytes == null || bytes > bestBytes) {
      bestBytes = bytes;
      bestName = parts.sublist(0, parts.length - 1).join(',').trim();
    }
  }
  return (name: bestName, memoryBytes: bestBytes);
}
