import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pistisai/models/log_entry.dart';

/// Reads and parses Hermes agent log files for the logs screen.
///
/// Hermes logs follow the format:
///   YYYY-MM-DD HH:MM:SS,mmm LEVEL component: message
///
/// Available log sources: agent, errors, gateway, desktop.
class LoggingService {
  final String _logDir;
  static const int _defaultLineLimit = 500;
  static const _logSources = ['agent', 'errors', 'gateway', 'desktop'];

  LoggingService({String? logDir})
      : _logDir = logDir ?? _defaultLogDir();

  static String _defaultLogDir() {
    try {
      final home = Platform.environment['LOCALAPPDATA'] ??
          Platform.environment['HOME'] ??
          Platform.environment['USERPROFILE'] ??
          '.';
      return '$home/hermes/logs';
    } catch (_) {
      return '.';
    }
  }

  /// Returns available log source names.
  List<String> get availableSources => _logSources;

  /// Reads the last [limit] lines from a log source.
  Future<List<LogEntry>> getLogs({
    String source = 'agent',
    int limit = _defaultLineLimit,
  }) async {
    final filePath = '$_logDir/$source.log';
    final file = File(filePath);

    if (!await file.exists()) {
      debugPrint('[LoggingService] Log file not found: $filePath');
      return [];
    }

    try {
      final lines = await _readLastLines(file, limit);
      return lines.map(_parseLine).whereType<LogEntry>().toList();
    } catch (e) {
      debugPrint('[LoggingService] Error reading $filePath: $e');
      return [];
    }
  }

  /// Returns logs from all available sources.
  Future<List<LogEntry>> getAllLogs({int limitPerSource = 100}) async {
    final allLogs = <LogEntry>[];
    for (final source in _logSources) {
      final logs = await getLogs(source: source, limit: limitPerSource);
      allLogs.addAll(logs);
    }
    allLogs.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return allLogs;
  }

  /// Read the last N lines from a file efficiently by reading from the end.
  Future<List<String>> _readLastLines(File file, int n) async {
    final raf = await file.open(mode: FileMode.read);
    try {
      final length = await raf.length();
      if (length == 0) return [];

      // Read last ~8KB or the whole file, whichever is smaller
      final chunkSize = (n * 200).clamp(1024, 65536);
      final startPos = length > chunkSize ? length - chunkSize : 0;

      await raf.setPosition(startPos);
      final bytes = await raf.read(length - startPos);
      final text = String.fromCharCodes(bytes);

      var lines = text.split('\n');
      // Remove partial first line if we started mid-file
      if (startPos > 0 && lines.isNotEmpty) {
        lines = lines.sublist(1);
      }
      // Remove trailing empty line
      if (lines.isNotEmpty && lines.last.isEmpty) {
        lines = lines.sublist(0, lines.length - 1);
      }

      return lines.length > n ? lines.sublist(lines.length - n) : lines;
    } finally {
      await raf.close();
    }
  }

  /// Parse a single log line into a LogEntry.
  /// Format: "YYYY-MM-DD HH:MM:SS,mmm LEVEL component: message"
  LogEntry? _parseLine(String line) {
    if (line.trim().isEmpty) return null;

    try {
      final parts = line.split(' ');
      if (parts.length < 4) return null;

      // Parse timestamp: YYYY-MM-DD HH:MM:SS,mmm
      final dateStr = '${parts[0]} ${parts[1]}';
      final timestamp = DateTime.tryParse(
        dateStr.replaceFirst(',', '.'),
      );
      if (timestamp == null) return null;

      // Parse level
      final levelStr = parts[2].toUpperCase();
      final severity = switch (levelStr) {
        'DEBUG' => LogSeverity.debug,
        'INFO' => LogSeverity.info,
        'WARNING' || 'WARN' => LogSeverity.warning,
        'ERROR' => LogSeverity.error,
        'CRITICAL' || 'FATAL' => LogSeverity.critical,
        _ => LogSeverity.info,
      };

      // Parse source and message: everything after the level
      final rest = parts.sublist(3).join(' ');
      final colonIdx = rest.indexOf(':');
      final source = colonIdx > 0 ? rest.substring(0, colonIdx).trim() : 'hermes';
      final message = colonIdx > 0
          ? rest.substring(colonIdx + 1).trim()
          : rest.trim();

      return LogEntry(
        id: '${timestamp.millisecondsSinceEpoch}_${line.hashCode}',
        timestamp: timestamp,
        severity: severity,
        source: source,
        message: message,
      );
    } catch (e) {
      return null;
    }
  }

  /// Formats a single [LogEntry] into the canonical export line:
  /// `[YYYY-MM-DD HH:MM:SS] [SEVERITY] [source] message`
  static String formatEntry(LogEntry log) {
    final timestamp = '${log.formatDate()} ${log.formatTimestamp()}';
    final severity = log.severityLabel.padRight(8);
    return '[$timestamp] [$severity] [${log.source}] ${log.message}';
  }

  /// Exports [entries] (or all available logs if null) to a `.log` file.
  ///
  /// By default the file is written to the app documents directory via
  /// [getApplicationDocumentsDirectory]. Pass [outputDir] to override the
  /// destination (mainly for tests or custom export locations).
  ///
  /// Returns the absolute file path on success, or `null` when export is not
  /// supported (e.g. web, or no logs to write) so callers can fall back to
  /// copying to the clipboard.
  Future<String?> exportLogs({
    List<LogEntry>? entries,
    String? fileName,
    String? outputDir,
  }) async {
    if (kIsWeb) return null;

    final logs = entries ?? await getAllLogs();
    if (logs.isEmpty) return null;

    try {
      final dirPath = outputDir ??
          (await getApplicationDocumentsDirectory()).path;
      final dir = Directory(dirPath);
      if (!await dir.exists()) await dir.create(recursive: true);

      final stamp =
          DateTime.now().toIso8601String().replaceAll(':', '-').split('.').first;
      final name = fileName ?? 'pistisai-logs-$stamp.log';
      final file = File(p.join(dir.path, name));
      final buffer = logs.map(formatEntry).join('\n');
      await file.writeAsString('$buffer\n');
      return file.path;
    } catch (e) {
      debugPrint('[LoggingService] Error exporting logs: $e');
      return null;
    }
  }
}
