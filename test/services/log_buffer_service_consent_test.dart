// Client logs leave the device only with crash-reporting consent (#1003).
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pistisai/services/log_buffer_service.dart';

class _RecordingAdapter implements HttpClientAdapter {
  final List<RequestOptions> requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return ResponseBody.fromString('{}', 200, headers: {
      Headers.contentTypeHeader: ['application/json'],
    });
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  late _RecordingAdapter adapter;
  late Dio dio;

  setUp(() {
    adapter = _RecordingAdapter();
    dio = Dio(BaseOptions(baseUrl: 'https://api.example.com'))
      ..httpClientAdapter = adapter;
  });

  void queueOne(LogBufferService service,
      {String url = 'https://app.example.com/chat'}) {
    service.queueForUpload(
      timestamp: '2026-01-01T00:00:00.000',
      level: 'INFO',
      message: 'hello',
      url: url,
      userAgent: 'test-agent',
    );
  }

  test('default service uploads nothing', () async {
    final service = LogBufferService.forTesting(
      dio: dio,
      uploadAllowed: () async => false,
    );
    queueOne(service);
    await service.flushForTesting();
    expect(adapter.requests, isEmpty);
    expect(service.pendingEntriesForTesting, isEmpty);
  });

  test('a thrown consent check counts as no consent', () async {
    final service = LogBufferService.forTesting(
      dio: dio,
      uploadAllowed: () async => throw StateError('prefs unavailable'),
    );
    queueOne(service);
    await service.flushForTesting();
    expect(adapter.requests, isEmpty);
  });

  test('uploads with consent and re-checks consent before each flush',
      () async {
    var allowed = true;
    final service = LogBufferService.forTesting(
      dio: dio,
      uploadAllowed: () async => allowed,
    );
    queueOne(service);
    await service.flushForTesting();
    expect(adapter.requests, hasLength(1));
    expect(adapter.requests.single.path, '/client-logs');

    allowed = false;
    queueOne(service);
    await service.flushForTesting();
    expect(adapter.requests, hasLength(1));
  });

  test('uploaded url has no query string or fragment', () async {
    final service = LogBufferService.forTesting(
      dio: dio,
      uploadAllowed: () async => true,
    );
    queueOne(service,
        url: 'https://app.example.com:8443/callback?code=SECRET#token=SECRET');
    expect(service.pendingEntriesForTesting.single['url'],
        'https://app.example.com:8443/callback');
    await service.flushForTesting();
    final data = adapter.requests.single.data as Map<String, dynamic>;
    final entries = data['entries'] as List<dynamic>;
    final entry = entries.single as Map<String, dynamic>;
    expect(entry['url'], 'https://app.example.com:8443/callback');
    expect(entry.toString(), isNot(contains('SECRET')));
  });

  test('sanitizeUrl drops query, fragment and user info', () {
    expect(
      LogBufferService.sanitizeUrl('https://user:pw@app.example.com/a/b?x=1#y'),
      'https://app.example.com/a/b',
    );
    expect(LogBufferService.sanitizeUrl('/relative/path?token=1'),
        '/relative/path');
  });
}
