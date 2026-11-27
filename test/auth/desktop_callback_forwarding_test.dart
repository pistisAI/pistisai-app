import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pistisai/brand/brand.dart';
import 'package:pistisai/main.dart' show forwardCallbackToRunningInstance;
import 'package:pistisai/utils/single_instance_io.dart';

/// #852 follow-up (review of #983): a sign-in callback that starts a second
/// desktop instance is forwarded to the running one instead of being dropped.
void main() {
  final callbackUrl =
      '${Brand.current.urlScheme}://callback?cf_jwt=header.payload.signature';

  group('forwardCallbackToRunningInstance', () {
    test('sends the callback URL found in the arguments', () async {
      final sent = <String>[];
      final ok = await forwardCallbackToRunningInstance(
        ['--verbose', callbackUrl],
        (url) async {
          sent.add(url);
          return true;
        },
      );
      expect(ok, isTrue);
      expect(sent, [callbackUrl]);
    });

    test('sends nothing when no callback URL is present', () async {
      var called = false;
      final ok = await forwardCallbackToRunningInstance(
        ['--enable-logging'],
        (url) async {
          called = true;
          return true;
        },
      );
      expect(ok, isFalse);
      expect(called, isFalse);
    });
  });

  group('SingleInstanceImpl loopback channel', () {
    late int port;
    late StreamController<String> received;

    setUp(() async {
      // Pick a free port so the test never collides with a running app.
      final probe = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      port = probe.port;
      await probe.close();
      received = StreamController<String>();
      final first = await SingleInstanceImpl.acquireLock(
        port: port,
        onForwardedUrl: received.add,
        accept: Brand.current.isCallbackUrl,
      );
      expect(first, isTrue);
    });

    tearDown(() async {
      await SingleInstanceImpl.releaseLock();
      // Not awaited: close() waits for a listener that some tests never add.
      unawaited(received.close());
    });

    test('a second instance cannot take the lock', () async {
      expect(await SingleInstanceImpl.acquireLock(port: port), isFalse);
    });

    test('delivers a forwarded callback URL to the first instance', () async {
      expect(
        await SingleInstanceImpl.forwardToRunningInstance(callbackUrl,
            port: port),
        isTrue,
      );
      expect(
        await received.stream.first.timeout(const Duration(seconds: 5)),
        callbackUrl,
      );
    });

    test('drops URLs the brand does not accept as callbacks', () async {
      await SingleInstanceImpl.forwardToRunningInstance(
          'https://evil.example.com/?cf_jwt=x',
          port: port);
      await SingleInstanceImpl.forwardToRunningInstance(callbackUrl,
          port: port);
      // Only the valid callback arrives.
      expect(
        await received.stream.first.timeout(const Duration(seconds: 5)),
        callbackUrl,
      );
    });

    test('drops over-long messages', () async {
      final socket = await Socket.connect(InternetAddress.loopbackIPv4, port);
      socket.add(List<int>.filled(
          SingleInstanceImpl.maxForwardedUrlLength + 10, 0x61));
      socket.add(const [10]);
      await socket.flush();
      await socket.close();
      socket.destroy();
      await SingleInstanceImpl.forwardToRunningInstance(callbackUrl,
          port: port);
      expect(
        await received.stream.first.timeout(const Duration(seconds: 5)),
        callbackUrl,
      );
    });

    test('refuses to send a URL with a line break or over the cap', () async {
      expect(
          await SingleInstanceImpl.forwardToRunningInstance('$callbackUrl\nx',
              port: port),
          isFalse);
      expect(
          await SingleInstanceImpl.forwardToRunningInstance(
              'a' * (SingleInstanceImpl.maxForwardedUrlLength + 1),
              port: port),
          isFalse);
    });
  });

  test('main.dart never prints command-line arguments', () {
    final source = File('lib/main.dart').readAsStringSync();
    final printsArgs = RegExp(r'debugPrint\([^;]*\$\{?args\b');
    expect(printsArgs.hasMatch(source), isFalse);
    expect(
        source.contains(
            r"debugPrint('[Main] Handling command-line arguments: $args')"),
        isFalse);
  });
}
