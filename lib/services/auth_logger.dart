// Simple auth logger for Pistisai
import 'package:flutter/foundation.dart';

import '../utils/file_download_helper.dart';

class AuthLogger {
  static final List<String> _logs = [];

  static String _formatEntry(String level, String message,
      [Map<String, dynamic>? data]) {
    final timestamp = DateTime.now().toIso8601String();
    final dataSuffix =
        data != null && data.isNotEmpty ? ' ${data.toString()}' : '';
    return '[$timestamp] [$level] $message$dataSuffix';
  }

  static void info(String message, [Map<String, dynamic>? data]) {
    final logEntry = _formatEntry('INFO', message, data);
    _logs.add(logEntry);
    if (kDebugMode) {
      debugPrint(logEntry);
    }
  }

  static void error(String message, [Map<String, dynamic>? data]) {
    final logEntry = _formatEntry('ERROR', message, data);
    _logs.add(logEntry);
    if (kDebugMode) {
      debugPrint(logEntry);
    }
  }

  static void debug(String message, [Map<String, dynamic>? data]) {
    final logEntry = _formatEntry('DEBUG', message, data);
    _logs.add(logEntry);
    if (kDebugMode) {
      debugPrint(logEntry);
    }
  }

  static void warning(String message, [Map<String, dynamic>? data]) {
    final logEntry = _formatEntry('WARNING', message, data);
    _logs.add(logEntry);
    if (kDebugMode) {
      debugPrint(logEntry);
    }
  }

  static List<String> getLogs() => List.unmodifiable(_logs);
  static void clearLogs() => _logs.clear();

  static void downloadLogs() {
    if (_logs.isEmpty) {
      return;
    }

    final content = '${_logs.join('\n')}\n';
    final bytes = content.codeUnits;
    final filename =
        'pistisai-auth-debug-${DateTime.now().toIso8601String().replaceAll(':', '-')}.log';

    if (kIsWeb) {
      downloadFile(bytes, filename, 'text/plain');
      return;
    }

    throw UnsupportedError(
      'Auth log download is only supported on web in debug mode',
    );
  }
}
