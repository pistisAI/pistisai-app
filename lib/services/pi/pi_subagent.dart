import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

/// Result from a Pi subagent execution.
class SubagentResult {
  final bool success;
  final String output;
  final String error;
  final int exitCode;
  final Duration duration;

  SubagentResult({
    required this.success,
    required this.output,
    required this.error,
    required this.exitCode,
    required this.duration,
  });

  @override
  String toString() =>
      'SubagentResult(success: $success, exitCode: $exitCode, '
      'output: ${output.length} chars, error: ${error.length} chars, '
      'duration: ${duration.inSeconds}s)';
}

/// Spawns Pi as a subagent for focused one-shot coding tasks.
///
/// Uses `pi --print` mode for headless execution. The active harness
/// delegates work, Pi does it, reports back.
///
/// Example:
/// ```dart
/// final subagent = PiSubagent();
/// final result = await subagent.execute(
///   'Fix the login button styling in lib/screens/login.dart',
///   cwd: '/dev/pistisai/pistisai-app',
/// );
/// if (result.success) {
///   print('Pi subagent completed: ${result.output}');
/// }
/// ```
class PiSubagent {
  String _provider;
  String _model;
  Duration _timeout;

  PiSubagent({
    String provider = 'llamacpp',
    String model = 'google_gemma-4-E4B-it',
    Duration timeout = const Duration(minutes: 10),
  })  : _provider = provider,
        _model = model,
        _timeout = timeout;

  /// Update the provider/model for subsequent calls.
  void configure({String? provider, String? model, Duration? timeout}) {
    if (provider != null) _provider = provider;
    if (model != null) _model = model;
    if (timeout != null) _timeout = timeout;
  }

  /// Execute a task via Pi in print mode.
  ///
  /// [task] is the natural language instruction.
  /// [cwd] is the working directory (defaults to /dev/pistisai).
  Future<SubagentResult> execute(String task, {String? cwd}) async {
    final stopwatch = Stopwatch()..start();

    try {
      debugPrint('[PiSubagent] Starting task: ${task.substring(0, task.length.clamp(0, 80))}...');

      final result = await Process.run(
        'pi',
        [
          '--print',
          '--provider', _provider,
          '--model', _model,
          task,
        ],
        workingDirectory: cwd ?? '/dev/pistisai',
        environment: {
          ...Platform.environment,
          // Ensure Pi can find llama-server
          'LLAMACPP_URL': 'http://127.0.0.1:8080/v1',
        },
      ).timeout(_timeout);

      stopwatch.stop();

      final output = result.stdout as String;
      final error = result.stderr as String;
      final exitCode = result.exitCode;

      debugPrint('[PiSubagent] Completed in ${stopwatch.elapsed.inSeconds}s (exit: $exitCode)');

      return SubagentResult(
        success: exitCode == 0,
        output: output.trim(),
        error: error.trim(),
        exitCode: exitCode,
        duration: stopwatch.elapsed,
      );
    } on TimeoutException {
      stopwatch.stop();
      debugPrint('[PiSubagent] Timed out after ${_timeout.inMinutes}m');
      return SubagentResult(
        success: false,
        output: '',
        error: 'Pi subagent timed out after ${_timeout.inMinutes} minutes',
        exitCode: -1,
        duration: stopwatch.elapsed,
      );
    } catch (e) {
      stopwatch.stop();
      debugPrint('[PiSubagent] Error: $e');
      return SubagentResult(
        success: false,
        output: '',
        error: 'Pi subagent error: $e',
        exitCode: -1,
        duration: stopwatch.elapsed,
      );
    }
  }

  /// Check if Pi is available on this system.
  static Future<bool> isAvailable() async {
    try {
      final result = await Process.run('pi', ['--version'])
          .timeout(const Duration(seconds: 5));
      return result.exitCode == 0;
    } catch (_) {
      return false;
    }
  }

  /// Get Pi version string.
  static Future<String?> version() async {
    try {
      final result = await Process.run('pi', ['--version'])
          .timeout(const Duration(seconds: 5));
      if (result.exitCode == 0) {
        return (result.stdout as String).trim();
      }
    } catch (_) {}
    return null;
  }
}
