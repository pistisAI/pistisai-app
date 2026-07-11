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

  /// Create a new scheduled job
  Future<bool> createJob({
    required String schedule,
    String? prompt,
    String? name,
    String? script,
    bool noAgent = false,
    String? workdir,
  }) async {
    try {
      final args = ['cron', 'create'];
      if (name != null && name.isNotEmpty) args.addAll(['--name', name]);
      if (script != null && script.isNotEmpty) args.addAll(['--script', script]);
      if (noAgent) args.add('--no-agent');
      if (workdir != null && workdir.isNotEmpty) args.addAll(['--workdir', workdir]);
      args.add(schedule);
      if (prompt != null && prompt.isNotEmpty) args.add(prompt);

      final r = await Process.run(
        _hermesPath,
        args,
        stdoutEncoding: utf8,
        stderrEncoding: utf8,
      );
      return r.exitCode == 0;
    } catch (e) {
      debugPrint('[CronService] Error creating job: $e');
      return false;
    }
  }

  /// Edit an existing scheduled job
  Future<bool> editJob({
    required String jobId,
    String? schedule,
    String? prompt,
    String? name,
    String? script,
    bool? noAgent,
    String? workdir,
  }) async {
    try {
      final args = ['cron', 'edit'];
      if (schedule != null && schedule.isNotEmpty) args.addAll(['--schedule', schedule]);
      if (prompt != null && prompt.isNotEmpty) args.addAll(['--prompt', prompt]);
      if (name != null && name.isNotEmpty) args.addAll(['--name', name]);
      if (script != null && script.isNotEmpty) args.addAll(['--script', script]);
      if (noAgent != null) {
        args.add(noAgent ? '--no-agent' : '--agent');
      }
      if (workdir != null && workdir.isNotEmpty) args.addAll(['--workdir', workdir]);
      args.add(jobId);

      final r = await Process.run(
        _hermesPath,
        args,
        stdoutEncoding: utf8,
        stderrEncoding: utf8,
      );
      return r.exitCode == 0;
    } catch (e) {
      debugPrint('[CronService] Error editing job: $e');
      return false;
    }
  }

  List<CronJob> _parse(String output) {
    final jobs = <CronJob>[];
    final lines = output.split('\n');
    String? id, status, name, schedule, cmd, workdir;
    DateTime? next, last;
    bool ok = true;
    bool noAgent = false;

    void flush() {
      if (id != null && name != null) {
        jobs.add(CronJob(
          id: id!, name: name!,
          schedule: schedule ?? '', scheduleDescription: schedule ?? '',
          command: cmd ?? '',
          status: status == 'active' ? CronJobStatus.active : CronJobStatus.inactive,
          nextRun: next, lastRun: last, lastRunSuccess: ok,
          noAgent: noAgent, workdir: workdir,
        ));
      }
      id = null; status = null; name = null; schedule = null; cmd = null; workdir = null;
      next = null; last = null; ok = true; noAgent = false;
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
      } else if (t.startsWith('Mode:')) {
        noAgent = t.substring(5).trim().contains('no-agent');
      } else if (t.startsWith('Workdir:')) {
        workdir = t.substring(8).trim();
      }
    }
    flush();
    return jobs;
  }
}
