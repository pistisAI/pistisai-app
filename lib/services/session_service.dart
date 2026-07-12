import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:pistisai/models/session.dart';

class SessionService {
  final String _hermesPath;
  SessionService({String? hermesPath}) : _hermesPath = hermesPath ?? 'hermes';

  Future<List<SessionData>> listSessions({int limit = 20}) async {
    try {
      final result = await Process.run(
        _hermesPath, ['sessions', 'list'],
        stdoutEncoding: utf8, stderrEncoding: utf8,
      );
      if (result.exitCode != 0) return [];
      return _parse(result.stdout as String).take(limit).toList();
    } catch (e) {
      debugPrint('[SessionService] Error: $e');
      return [];
    }
  }

  List<SessionData> _parse(String output) {
    final sessions = <SessionData>[];
    final lines = output.split('\n');
    var headerFound = false;

    for (final line in lines) {
      final t = line.trim();
      if (t.isEmpty) continue;
      if (!headerFound) {
        if (t.contains('Title') && t.contains('Preview') && t.contains('ID')) {
          headerFound = true;
        }
        continue;
      }
      if (t.startsWith('─')) continue;

      // Parse: "Title · date   Preview   Ago   ID"
      // Fields separated by 2+ spaces
      final parts = t.split(RegExp(r'\s{2,}'));
      if (parts.length < 2) continue;

      final id = parts.last.trim();
      final title = parts.first.trim();

      final type = id.startsWith('cron_') ? 'cron' : 'agent';

      sessions.add(SessionData(
        id: id,
        type: type,
        userOrAgent: title.length > 40 ? '${title.substring(0, 40)}...' : title,
        startTime: DateTime.now(),
        tokenUsage: 0,
        messageCount: 0,
        status: 'active',
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
