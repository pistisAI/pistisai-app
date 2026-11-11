import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pistisai/services/cron_service.dart';

void main() {
  late List<List<String>> calls;
  late CronService service;

  setUp(() {
    calls = [];
    service = CronService(
      hermesPath: 'hermes',
      processRunner: (executable, arguments) async {
        calls.add([executable, ...arguments]);
        return ProcessResult(0, 0, '', '');
      },
    );
  });

  group('isSafeCronText', () {
    test('accepts ordinary names, schedules, prompts and paths', () {
      for (final value in [
        'Morning report',
        'every 30m',
        '0 9 * * *',
        '*/5 * * * 1-5',
        'Summarise my inbox & flag anything urgent (top 3)!',
        r'C:\Users\someone\My Scripts\job.py',
        '/home/someone/my scripts/job.sh',
      ]) {
        expect(isSafeCronText(value), isTrue, reason: value);
      }
    });

    test('refuses empty text, option-like text and control characters', () {
      for (final value in [
        '',
        '   ',
        '--script /tmp/x',
        ' -n',
        'two\nlines',
        'tab\there',
        'nul\x00byte',
      ]) {
        expect(isSafeCronText(value), isFalse, reason: value);
      }
    });
  });

  group('createJob', () {
    test('passes text with spaces as single arguments', () async {
      final ok = await service.createJob(
        name: 'Morning report',
        schedule: 'every 30m',
        prompt: 'Summarise my inbox',
      );

      expect(ok, isTrue);
      expect(calls.single, [
        'hermes',
        'cron',
        'create',
        '--name',
        'Morning report',
        'every 30m',
        'Summarise my inbox',
      ]);
    });

    test('does not run the command for an option-like value', () async {
      final ok = await service.createJob(
        schedule: 'every 30m',
        prompt: '--script /tmp/x',
      );

      expect(ok, isFalse);
      expect(calls, isEmpty);
    });
  });

  group('editJob', () {
    test('passes a cron expression and a prompt with spaces', () async {
      final ok = await service.editJob(
        jobId: 'abc123',
        schedule: '0 9 * * *',
        prompt: 'Summarise my inbox',
      );

      expect(ok, isTrue);
      expect(calls.single, [
        'hermes',
        'cron',
        'edit',
        '--schedule',
        '0 9 * * *',
        '--prompt',
        'Summarise my inbox',
        'abc123',
      ]);
    });

    test('still refuses an unsafe job id', () async {
      expect(
        await service.editJob(jobId: 'abc; rm', schedule: 'every 1h'),
        isFalse,
      );
      expect(await service.removeJob('--all'), isFalse);
      expect(calls, isEmpty);
    });
  });
}
