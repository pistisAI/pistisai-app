import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:pistisai/models/cron_job.dart';

class CronService {
  final String _hermesPath;

  CronService({String? hermesPath}) : _hermesPath = hermesPath ?? 'hermes';

  Future<List<CronJob>> listJobs() async {
    try {
      final result = await Process.run(
        _hermesPath, ['cron', 'list'],
        stdoutEncoding: utf8, stderrEncoding: utf8,
      );
      if (result.exitCode != 0) return [];
      return _parse(result.stdout as String);
    } catch (e) {
      debugPrint('[CronService] Error: $e');
      return [];
    }
  }

  Future<bool> toggleJob(String jobId, bool active) async {
    try {
      final action = active ? 'pause' : 'resume';
      final r = await Process.run(_hermesPath, ['cron', action, jobId],
        stdoutEncoding: utf8, stderrEncoding: utf8);
      return r.exitCode == 0;
    } catch (e) { return false; }
  }

  Future<bool> runJobNow(String jobId) async {
    try {
      final r = await Process.run(_hermesPath, ['cron', 'run', jobId],
        stdoutEncoding: utf8, stderrEncoding: utf8);
      return r.exitCode == 0;
    } catch (e) { return false; }
  }

  Future<bool> removeJob(String jobId) async {
    try {
      final r = await Process.run(_hermesPath, ['cron', 'remove', jobId],
        stdoutEncoding: utf8, stderrEncoding: utf8);
      return r.exitCode == 0;
    } catch (e) { return false; }
  }

  List<CronJob> _parse(String output) {
    final jobs = <CronJob>[];
    final lines = output.split('\n');
    String? id, status, name, schedule, cmd;
    DateTime? next, last;
    bool ok = true;

    void flush() {
      if (id != null && name != null) {
        jobs.add(CronJob(
          id: id!, name: name!,
          schedule: schedule ?? '', scheduleDescription: schedule ?? '',
          command: cmd ?? '',
          status: status == 'active' ? CronJobStatus.active : CronJobStatus.inactive,
          nextRun: next, lastRun: last, lastRunSuccess: ok,
        ));
      }
      id = null; status = null; name = null; schedule = null; cmd = null;
      next = null; last = null; ok = true;
    }

    for (final line in lines) {
      final t = line.trim();
      if (t.isEmpty || t.startsWith('┌') || t.startsWith('└') || t.startsWith('│')) continue;

      final idMatch = RegExp(r'^(\S+)\s+\[(\w+)\]').firstMatch(t);
      if (idMatch != null) {
        flush();
        id = idMatch.group(1);
        status = idMatch.group(2);
        continue;
      }
      if (id == null) continue;

      if (t.startsWith('Name:')) {
        name = t.substring(5).trim();
      } else if (t.startsWith('Schedule:')) {
        schedule = t.substring(9).trim();
      } else if (t.startsWith('Next run:')) {
        next = DateTime.tryParse(t.substring(9).trim());
      } else if (t.startsWith('Last run:')) {
        final p = t.substring(9).trim();
        if (p.contains('  ')) {
          final parts = p.split('  ');
          last = DateTime.tryParse(parts[0].trim());
          ok = parts[1].trim() == 'ok';
        } else {
          last = DateTime.tryParse(p);
        }
      } else if (t.startsWith('Script:')) {
        cmd = t.substring(7).trim();
      }
    }
    flush();
    return jobs;
  }
}
