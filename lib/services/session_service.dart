import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:pistisai/models/session.dart';

typedef SessionProcessRunner = Future<ProcessResult> Function(
  String executable,
  List<String> arguments,
);

Future<ProcessResult> _runProcess(String executable, List<String> arguments) =>
    Process.run(
      executable,
      arguments,
      stdoutEncoding: utf8,
      stderrEncoding: utf8,
    );

class SessionServiceException implements Exception {
  SessionServiceException(this.message);
  final String message;
  @override
  String toString() => message;
}

class SessionService {
  final String _hermesPath;
  final SessionProcessRunner _run;
  SessionService({String? hermesPath, SessionProcessRunner? processRunner})
      : _hermesPath = hermesPath ?? 'hermes',
        _run = processRunner ?? _runProcess;

  /// Lists Hermes sessions. Throws [SessionServiceException] when the
  /// `hermes` command is missing or fails, so the screen shows an error
  /// instead of an empty list.
  Future<List<SessionData>> listSessions({int limit = 20}) async {
    final ProcessResult result;
    try {
      result = await _run(_hermesPath, ['sessions', 'list']);
    } catch (e) {
      debugPrint('[SessionService] Error: $e');
      throw SessionServiceException(
          'Could not run "$_hermesPath sessions list": $e');
    }
    if (result.exitCode != 0) {
      final stderr = '${result.stderr}'.trim();
      throw SessionServiceException(
        '"$_hermesPath sessions list" exited with code ${result.exitCode}'
        '${stderr.isEmpty ? '' : ': $stderr'}',
      );
    }
    return parseSessionList(result.stdout as String).take(limit).toList();
  }

  /// Parses the table printed by `hermes sessions list`:
  /// `Title   Preview   Last Active   ID`, columns separated by 2+ spaces.
  @visibleForTesting
  static List<SessionData> parseSessionList(String output) {
    final sessions = <SessionData>[];
    bool headerFound = false;

    for (final line in output.split('\n')) {
      final t = line.trim();
      if (t.isEmpty) continue;
      if (!headerFound) {
        if (t.contains('Title') && t.contains('ID')) {
          headerFound = true;
        }
        continue;
      }
      if (t.startsWith('─') || t.startsWith('-')) continue;

      final parts = t.split(RegExp(r'\s{2,}'));
      if (parts.length < 2) continue;

      final id = parts.last.trim();
      final title = parts.first.trim();
      String? preview;
      String? lastActive;
      if (parts.length >= 4) {
        preview = parts[parts.length - 3].trim();
        lastActive = parts[parts.length - 2].trim();
      } else if (parts.length == 3) {
        lastActive = parts[1].trim();
      }

      sessions.add(SessionData(
        id: id,
        type: id.startsWith('cron_') ? 'cron' : 'agent',
        userOrAgent: title.length > 40 ? '${title.substring(0, 40)}...' : title,
        preview: (preview == null || preview.isEmpty) ? null : preview,
        lastActive:
            (lastActive == null || lastActive.isEmpty) ? null : lastActive,
      ));
    }
    return sessions;
  }

  /// Terminates a session by id via the Hermes CLI.
  ///
  /// Returns `true` when the underlying command exits cleanly, `false` on
  /// failure or when the Hermes runtime is unavailable.
  Future<bool> terminate(String id) async {
    try {
      final result = await Process.run(
        _hermesPath,
        ['sessions', 'terminate', id],
        stdoutEncoding: utf8,
        stderrEncoding: utf8,
      );
      if (result.exitCode != 0) {
        debugPrint('[SessionService] terminate failed (${result.exitCode}): '
            '${result.stderr}');
        return false;
      }
      return true;
    } catch (e) {
      debugPrint('[SessionService] Error terminating session: $e');
      return false;
    }
  }
}
