import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

class CloudTtsRequest {
  const CloudTtsRequest({
    required this.input,
    this.model = 'pistisai-edge-tts',
    this.voice = 'en-US-GuyNeural',
    this.responseFormat = 'mp3',
    this.speed = 1.0,
  });

  factory CloudTtsRequest.fromJson(Map<String, dynamic> json) {
    final input = json['input'];
    if (input is! String || input.trim().isEmpty) {
      throw const FormatException('Missing required string field: input');
    }

    return CloudTtsRequest(
      input: input,
      model: _stringOrDefault(json['model'], 'pistisai-edge-tts'),
      voice: _stringOrDefault(json['voice'], 'en-US-GuyNeural'),
      responseFormat: _normalizeFormat(
        _stringOrDefault(json['response_format'], 'mp3'),
      ),
      speed: _numberOrDefault(json['speed'], 1.0),
    );
  }

  final String input;
  final String model;
  final String voice;
  final String responseFormat;
  final double speed;

  static String _stringOrDefault(dynamic value, String fallback) {
    if (value is String && value.trim().isNotEmpty) {
      return value.trim();
    }
    return fallback;
  }

  static double _numberOrDefault(dynamic value, double fallback) {
    if (value is num && value.isFinite) {
      return value.toDouble();
    }
    return fallback;
  }

  static String _normalizeFormat(String raw) {
    final normalized = raw.toLowerCase().trim();
    return switch (normalized) {
      'mp3' || 'mpeg' => 'mp3',
      'wav' => 'wav',
      'opus' || 'ogg' => 'opus',
      _ => 'mp3',
    };
  }
}

class CloudTtsResult {
  const CloudTtsResult({
    required this.path,
    required this.contentType,
  });

  final String path;
  final String contentType;
}

typedef CloudTtsProcessRunner = Future<ProcessResult> Function(
  String executable,
  List<String> arguments, {
  Map<String, String>? environment,
  bool runInShell,
});

class CloudTtsService {
  CloudTtsService({
    CloudTtsProcessRunner? processRunner,
    String? ttsCommand,
    String? ffmpegCommand,
    Directory? outputDirectory,
    Duration timeout = const Duration(seconds: 45),
  })  : _processRunner = processRunner ?? Process.run,
        _ttsCommand = ttsCommand ??
            Platform.environment['pistisai_TTS_COMMAND'] ??
            'edge-tts',
        _ffmpegCommand = ffmpegCommand ??
            Platform.environment['pistisai_FFMPEG_COMMAND'] ??
            'ffmpeg',
        _outputDirectory = outputDirectory ??
            Directory(defaultCacheDirectory(
              Platform.environment,
              tempDirectory: Directory.systemTemp.path,
            )),
        _timeout = timeout;

  final CloudTtsProcessRunner _processRunner;
  final String _ttsCommand;
  final String _ffmpegCommand;
  final Directory _outputDirectory;
  final Duration _timeout;

  Future<CloudTtsResult> synthesize(CloudTtsRequest request) async {
    await _outputDirectory.create(recursive: true);
    final startedAt = DateTime.now().microsecondsSinceEpoch;
    final basePath = p.join(_outputDirectory.path, 'speech_$startedAt');
    final mp3Path = '$basePath.mp3';

    final args = <String>[
      '--voice',
      request.voice,
      '--text',
      request.input,
      '--write-media',
      mp3Path,
    ];

    final result = await _processRunner(
      _ttsCommand,
      args,
      environment: _mergedPathEnvironment(),
      runInShell: false,
    ).timeout(_timeout);

    if (result.exitCode != 0) {
      throw ProcessException(
        _ttsCommand,
        args,
        _processOutput(result),
        result.exitCode,
      );
    }

    final mp3File = File(mp3Path);
    if (!await mp3File.exists() || await mp3File.length() == 0) {
      throw StateError('TTS command produced no audio output at $mp3Path');
    }

    if (request.responseFormat == 'mp3') {
      return CloudTtsResult(path: mp3Path, contentType: 'audio/mpeg');
    }

    final targetPath =
        '$basePath.${request.responseFormat == 'opus' ? 'ogg' : 'wav'}';
    await _convertAudio(
      inputPath: mp3Path,
      outputPath: targetPath,
      responseFormat: request.responseFormat,
    );

    return CloudTtsResult(
      path: targetPath,
      contentType: request.responseFormat == 'opus' ? 'audio/ogg' : 'audio/wav',
    );
  }

  Future<void> _convertAudio({
    required String inputPath,
    required String outputPath,
    required String responseFormat,
  }) async {
    final args = responseFormat == 'opus'
        ? <String>[
            '-y',
            '-i',
            inputPath,
            '-acodec',
            'libopus',
            '-ac',
            '1',
            '-b:a',
            '64k',
            '-vbr',
            'off',
            outputPath,
          ]
        : <String>['-y', '-i', inputPath, outputPath];

    final result = await _processRunner(
      _ffmpegCommand,
      args,
      environment: _mergedPathEnvironment(),
      runInShell: false,
    ).timeout(_timeout);

    if (result.exitCode != 0) {
      throw ProcessException(
        _ffmpegCommand,
        args,
        _processOutput(result),
        result.exitCode,
      );
    }

    final outputFile = File(outputPath);
    if (!await outputFile.exists() || await outputFile.length() == 0) {
      throw StateError('ffmpeg produced no audio output at $outputPath');
    }
  }

  /// The user's home directory: `HOME`, else `USERPROFILE` (Windows often
  /// has no `HOME`). Null when neither is set, so callers never resolve a
  /// path against the process working directory by accident.
  static String? homeDirectory(Map<String, String> environment) {
    for (final name in const ['HOME', 'USERPROFILE']) {
      final value = environment[name];
      if (value != null && value.trim().isNotEmpty) return value;
    }
    return null;
  }

  /// Where generated speech is cached. Falls back to [tempDirectory] when
  /// there is no home directory.
  static String defaultCacheDirectory(
    Map<String, String> environment, {
    required String tempDirectory,
    p.Context? pathContext,
  }) {
    final ctx = pathContext ?? p.context;
    final xdg = environment['XDG_CACHE_HOME'];
    final home = homeDirectory(environment);
    final base = (xdg != null && xdg.trim().isNotEmpty)
        ? xdg
        : home != null
            ? ctx.join(home, '.cache')
            : tempDirectory;
    return ctx.join(base, 'pistisai', 'tts');
  }

  /// [environment] with the Hermes virtual-env tools prepended to `PATH`.
  /// Left unchanged when there is no home directory to find Hermes in.
  static Map<String, String> pathEnvironment(
    Map<String, String> environment, {
    required bool isWindows,
    p.Context? pathContext,
  }) {
    final ctx = pathContext ?? p.context;
    final env = Map<String, String>.from(environment);
    final home = homeDirectory(environment);
    if (home == null) return env;
    final hermesVenvBin = ctx.join(
      home,
      '.hermes',
      'hermes-agent',
      'venv',
      isWindows ? 'Scripts' : 'bin',
    );
    final separator = isWindows ? ';' : ':';
    // Windows environment names are case-insensitive ("Path" is common).
    final pathKey = env.keys.firstWhere(
      (k) => k.toUpperCase() == 'PATH',
      orElse: () => 'PATH',
    );
    final currentPath = env[pathKey] ?? '';
    if (!currentPath.split(separator).contains(hermesVenvBin)) {
      env[pathKey] = currentPath.isEmpty
          ? hermesVenvBin
          : '$hermesVenvBin$separator$currentPath';
    }
    return env;
  }

  Map<String, String> _mergedPathEnvironment() =>
      pathEnvironment(Platform.environment, isWindows: Platform.isWindows);

  String _processOutput(ProcessResult result) {
    final stderrText = _stringifyProcessStream(result.stderr);
    if (stderrText.trim().isNotEmpty) {
      return stderrText.trim();
    }
    return _stringifyProcessStream(result.stdout).trim();
  }

  String _stringifyProcessStream(dynamic value) {
    if (value is String) {
      return value;
    }
    if (value is List<int>) {
      return utf8.decode(value, allowMalformed: true);
    }
    return value?.toString() ?? '';
  }
}
