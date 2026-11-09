import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pistisai/models/log_entry.dart';
import 'package:pistisai/services/logging_service.dart';

LogEntry _entry({
  required String id,
  required DateTime ts,
  required LogSeverity severity,
  required String source,
  required String message,
}) =>
    LogEntry(
      id: id,
      timestamp: ts,
      severity: severity,
      source: source,
      message: message,
    );

void main() {
  group('LoggingService.formatEntry', () {
    test('formats the canonical export line', () {
      final entry = _entry(
        id: '1',
        ts: DateTime(2026, 5, 9, 13, 30, 15),
        severity: LogSeverity.error,
        source: 'gateway',
        message: 'connection dropped',
      );

      expect(
        LoggingService.formatEntry(entry),
        '[2026-05-09 13:30:15] [ERROR   ] [gateway] connection dropped',
      );
    });
  });

  group('LoggingService.exportLogs', () {
    test('writes entries to a file and returns the path', () async {
      final entries = [
        _entry(
          id: '1',
          ts: DateTime(2026, 5, 9, 13, 30, 15),
          severity: LogSeverity.info,
          source: 'agent',
          message: 'started',
        ),
        _entry(
          id: '2',
          ts: DateTime(2026, 5, 9, 13, 31, 2),
          severity: LogSeverity.warning,
          source: 'desktop',
          message: 'low memory',
        ),
      ];

      final dir = await Directory.systemTemp.createTemp('pistisai-logs-');
      final service = LoggingService();
      final path = await service.exportLogs(
        entries: entries,
        outputDir: dir.path,
      );

      expect(path, isNotNull);
      final file = File(path!);
      expect(await file.exists(), isTrue);

      final contents = await file.readAsString();
      expect(
        contents,
        contains('[2026-05-09 13:30:15] [INFO    ] [agent] started'),
      );
      expect(
        contents,
        contains('[2026-05-09 13:31:02] [WARNING ] [desktop] low memory'),
      );

      // Cleanup so the on-disk export does not accumulate between runs.
      await dir.delete(recursive: true);
    });

    test('returns null when there are no entries to export', () async {
      final service = LoggingService();
      final path = await service.exportLogs(entries: []);
      expect(path, isNull);
    });
  });
}
