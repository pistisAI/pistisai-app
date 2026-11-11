import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:pistisai/services/voice/cloud_tts_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CloudTtsRequest', () {
    test('parses OpenAI-compatible speech request defaults', () {
      final request = CloudTtsRequest.fromJson({'input': 'hello there'});

      expect(request.input, 'hello there');
      expect(request.model, 'pistisai-edge-tts');
      expect(request.voice, 'en-US-GuyNeural');
      expect(request.responseFormat, 'mp3');
    });

    test('normalizes opus aliases', () {
      final request = CloudTtsRequest.fromJson({
        'input': 'hello there',
        'response_format': 'ogg',
      });

      expect(request.responseFormat, 'opus');
    });

    test('rejects missing input', () {
      expect(
        () => CloudTtsRequest.fromJson({'voice': 'en-US-GuyNeural'}),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('CloudTtsService', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('ctllm_tts_test_');
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('invokes edge-tts-compatible command and returns mp3 output',
        () async {
      final service = CloudTtsService(
        outputDirectory: tempDir,
        processRunner: (executable, arguments,
            {environment, runInShell = false}) async {
          expect(executable, 'edge-tts');
          final outputIndex = arguments.indexOf('--write-media');
          expect(outputIndex, greaterThan(-1));
          final outputPath = arguments[outputIndex + 1];
          await File(outputPath).writeAsBytes(<int>[0, 1, 2, 3]);
          return ProcessResult(42, 0, '', '');
        },
      );

      final result = await service.synthesize(
        const CloudTtsRequest(input: 'Pistisai voice works.'),
      );

      expect(result.contentType, 'audio/mpeg');
      expect(result.path.endsWith('.mp3'), isTrue);
      expect(await File(result.path).length(), 4);
    });
  });

  group('CloudTtsService paths', () {
    final win = p.Context(style: p.Style.windows);
    final posix = p.Context(style: p.Style.posix);

    test('uses HOME when it is set', () {
      expect(
        CloudTtsService.homeDirectory({'HOME': '/home/u', 'USERPROFILE': 'x'}),
        '/home/u',
      );
    });

    test('falls back to USERPROFILE when HOME is missing or blank', () {
      expect(
        CloudTtsService.homeDirectory({'USERPROFILE': r'C:\Users\u'}),
        r'C:\Users\u',
      );
      expect(
        CloudTtsService.homeDirectory(
            {'HOME': ' ', 'USERPROFILE': r'C:\Users\u'}),
        r'C:\Users\u',
      );
    });

    test('has no home directory when neither variable is set', () {
      expect(CloudTtsService.homeDirectory(const {}), isNull);
    });

    test('adds the Hermes venv from USERPROFILE to the Windows Path', () {
      final env = CloudTtsService.pathEnvironment(
        {'USERPROFILE': r'C:\Users\u', 'Path': r'C:\Windows'},
        isWindows: true,
        pathContext: win,
      );

      expect(
        env['Path'],
        r'C:\Users\u\.hermes\hermes-agent\venv\Scripts;C:\Windows',
      );
      expect(env.containsKey('PATH'), isFalse);
    });

    test('adds the Hermes venv from HOME once on POSIX', () {
      final first = CloudTtsService.pathEnvironment(
        {'HOME': '/home/u', 'PATH': '/usr/bin'},
        isWindows: false,
        pathContext: posix,
      );
      final second = CloudTtsService.pathEnvironment(
        first,
        isWindows: false,
        pathContext: posix,
      );

      expect(first['PATH'], '/home/u/.hermes/hermes-agent/venv/bin:/usr/bin');
      expect(second['PATH'], first['PATH']);
    });

    test('leaves PATH alone when there is no home directory', () {
      final env = CloudTtsService.pathEnvironment(
        {'PATH': '/usr/bin'},
        isWindows: false,
        pathContext: posix,
      );

      expect(env, {'PATH': '/usr/bin'});
    });

    test('caches under the temp directory, never the working directory', () {
      expect(
        CloudTtsService.defaultCacheDirectory(
          const {},
          tempDirectory: '/tmp',
          pathContext: posix,
        ),
        '/tmp/pistisai/tts',
      );
      expect(
        CloudTtsService.defaultCacheDirectory(
          {'USERPROFILE': r'C:\Users\u'},
          tempDirectory: r'C:\Temp',
          pathContext: win,
        ),
        r'C:\Users\u\.cache\pistisai\tts',
      );
    });
  });
}
