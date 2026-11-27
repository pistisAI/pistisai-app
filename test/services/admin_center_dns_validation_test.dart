// POST /admin/dns/validate answers 200 with valid:false and an errors list
// for bad records; the service must surface that, not hide it. See #1004.
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pistisai/services/admin_center_service.dart';

import '../helpers/mock_services.dart';

class _JsonAdapter implements HttpClientAdapter {
  _JsonAdapter(this.body);

  final Object body;
  RequestOptions? lastRequest;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastRequest = options;
    return ResponseBody.fromString(
      jsonEncode(body),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

AdminCenterService _serviceWith(_JsonAdapter adapter) {
  final dio = Dio()..httpClientAdapter = adapter;
  return AdminCenterService(authService: MockAuthService(), dio: dio);
}

void main() {
  test('parses valid:false and the per-record errors', () async {
    final adapter = _JsonAdapter({
      'success': true,
      'data': {
        'valid': false,
        'records': [],
        'errors': [
          {
            'recordId': 'rec-1',
            'recordType': 'DKIM',
            'error': 'Value mismatch',
          },
        ],
      },
    });
    final service = _serviceWith(adapter);
    addTearDown(service.dispose);

    final result = await service.validateDnsRecords();

    expect(adapter.lastRequest?.path, '/admin/dns/validate');
    expect(result.valid, isFalse);
    expect(result.errors, hasLength(1));
    expect(result.errors.single.recordId, 'rec-1');
    expect(result.errors.single.recordType, 'DKIM');
    expect(result.errors.single.message, 'Value mismatch');
  });

  test('valid:true parses as valid with no errors', () async {
    final service = _serviceWith(_JsonAdapter({
      'success': true,
      'data': {'valid': true, 'records': [], 'errors': []},
    }));
    addTearDown(service.dispose);

    final result = await service.validateDnsRecords();

    expect(result.valid, isTrue);
    expect(result.errors, isEmpty);
  });

  test('a response without a valid flag is not treated as valid', () async {
    final service = _serviceWith(_JsonAdapter({'success': true, 'data': {}}));
    addTearDown(service.dispose);

    final result = await service.validateDnsRecords();

    expect(result.valid, isFalse);
  });
}
