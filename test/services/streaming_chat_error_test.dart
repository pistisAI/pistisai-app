import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:pistisai/services/streaming_chat_service.dart';

void main() {
  test('disconnected chat error never includes exception types', () {
    final message = userFacingChatError(
      TimeoutException('Future not completed'),
      isConnected: false,
    );
    expect(message, contains('No agent runtime connected'));
    expect(message, isNot(contains('TimeoutException')));
  });

  test('connected timeout is mapped to a human sentence', () {
    final message = userFacingChatError(
      TimeoutException('Future not completed'),
      isConnected: true,
    );
    expect(message, contains('did not respond in time'));
    expect(message, isNot(contains('TimeoutException')));
  });

  test('empty reply surfaces a user-facing message without exception types',
      () {
    final message = userFacingEmptyReply();
    expect(message, contains('without a reply'));
    expect(message, isNot(contains('Exception')));
    expect(message, isNot(contains('null')));
  });
}
