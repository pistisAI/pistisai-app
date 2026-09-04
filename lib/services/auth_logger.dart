// Simple auth logger for Pistisai
import 'package:flutter/foundation.dart';
import '../utils/file_download_helper.dart';

class AuthLogger {
  static final List<String> _logs = [];

  static void info(String message, [Map<String, dynamic>? data]) {
    final logEntry = '[INFO]  ';
    _logs.add(logEntry);
    if (kDebugMode) {
      debugPrint(' ');
    }
  }

  static void error(String message, [Map<String, dynamic>? data]) {
    final logEntry = '[ERROR]  ';
    _logs.add(logEntry);
    if (kDebugMode) {
      debugPrint('  ');
    }
  }

  static void debug(String message, [Map<String, dynamic>? data]) {
    final logEntry = '[DEBUG]  ';
    _logs.add(logEntry);
    if (kDebugMode) {
      debugPrint(' � ');
    }
  }

  static void warning(String message, [Map<String, dynamic>? data]) {
    final logEntry = '[WARNING]  ';
    _logs.add(logEntry);
    if (kDebugMode) {
      debugPrint('��  ');
    }
  }

  static List<String> getLogs() => List.from(_logs);
  static void clearLogs() => _logs.clear();

  static Future<void> downloadLogs() async {
    final buffer = StringBuffer();
    buffer.writeln('# Pistisai Auth Debug Log');
    buffer.writeln('Generated at: ${DateTime.now().toIso8601String()}');
    buffer.writeln('Log entries: ${_logs.length}');
    buffer.writeln('');
    for (final log in _logs) {
      buffer.writeln(log);
    }
    final bytes = buffer.toString().codeUnits;
    downloadFile(bytes, 'pistisai_auth_debug_${DateTime.now().millisecondsSinceEpoch}.log', 'text/plain');
  }
}
