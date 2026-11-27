import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Desktop implementation using a loopback TCP socket.
///
/// If another instance is already listening on the port, the bind fails and
/// we know we're a duplicate. The socket stays open for the life of the
/// process — when the app exits, the OS releases it automatically.
///
/// The same socket carries one message from a second instance to the first:
/// a sign-in callback URL (`pistisai://callback?...`) the OS handed to the
/// second launch. The first instance reads one line, at most
/// [maxForwardedUrlLength] bytes, from loopback peers only, and passes it on
/// only when the `accept` predicate given to [acquireLock] allows it (#852).
class SingleInstanceImpl {
  static ServerSocket? _socket;

  /// A port unlikely to collide with common dev services.
  /// 27182 = digits of e, chosen to avoid 3000/8080/1337/etc.
  static const int _lockPort = 27182;

  /// Upper bound for a forwarded URL. Access JWTs are a few KiB.
  static const int maxForwardedUrlLength = 16 * 1024;

  static const Duration _readTimeout = Duration(seconds: 5);

  static Future<bool> acquireLock({
    void Function(String url)? onForwardedUrl,
    bool Function(String url)? accept,
    int port = _lockPort,
  }) async {
    try {
      _socket = await ServerSocket.bind(
        InternetAddress.loopbackIPv4,
        port,
        shared: false,
      );
    } on SocketException {
      return false;
    }
    final handler = onForwardedUrl;
    _socket!.listen(
      (client) {
        if (handler == null) {
          client.destroy();
          return;
        }
        unawaited(_readForwardedUrl(client, handler, accept));
      },
      onError: (Object _) {},
    );
    return true;
  }

  static Future<void> _readForwardedUrl(
    Socket client,
    void Function(String url) handler,
    bool Function(String url)? accept,
  ) async {
    final url = await readForwardedLine(client, accept: accept);
    if (url != null) {
      handler(url);
    }
  }

  /// Read one forwarded line from [client] and close it. Returns null for a
  /// non-loopback peer, an empty or over-long message, a read timeout, or a
  /// line that [accept] refuses.
  static Future<String?> readForwardedLine(
    Socket client, {
    bool Function(String url)? accept,
  }) async {
    try {
      if (!client.remoteAddress.isLoopback) {
        return null;
      }
      final bytes = <int>[];
      var tooLong = false;
      final done = Completer<void>();
      late final StreamSubscription<List<int>> sub;
      sub = client.listen(
        (chunk) {
          final newline = chunk.indexOf(10);
          final part = newline >= 0 ? chunk.sublist(0, newline) : chunk;
          if (bytes.length + part.length > maxForwardedUrlLength) {
            tooLong = true;
          } else {
            bytes.addAll(part);
          }
          if (newline >= 0 || tooLong) {
            if (!done.isCompleted) done.complete();
          }
        },
        onDone: () {
          if (!done.isCompleted) done.complete();
        },
        onError: (Object _) {
          tooLong = true;
          if (!done.isCompleted) done.complete();
        },
        cancelOnError: true,
      );
      await done.future.timeout(_readTimeout, onTimeout: () => tooLong = true);
      await sub.cancel();
      if (tooLong || bytes.isEmpty) {
        return null;
      }
      final line = utf8.decode(bytes, allowMalformed: false).trim();
      if (line.isEmpty) {
        return null;
      }
      if (accept != null && !accept(line)) {
        return null;
      }
      return line;
    } catch (_) {
      return null;
    } finally {
      client.destroy();
    }
  }

  /// Send [url] to the instance that holds the lock. Returns true once the
  /// line was written. Refuses URLs over [maxForwardedUrlLength] bytes or
  /// containing a line break.
  static Future<bool> forwardToRunningInstance(
    String url, {
    int port = _lockPort,
  }) async {
    final bytes = utf8.encode(url);
    if (bytes.isEmpty ||
        bytes.length > maxForwardedUrlLength ||
        url.contains('\n') ||
        url.contains('\r')) {
      return false;
    }
    Socket? socket;
    try {
      socket = await Socket.connect(
        InternetAddress.loopbackIPv4,
        port,
        timeout: const Duration(seconds: 3),
      );
      socket.add(bytes);
      socket.add(const [10]);
      await socket.flush();
      await socket.close();
      return true;
    } catch (_) {
      socket?.destroy();
      return false;
    }
  }

  static Future<void> releaseLock() async {
    await _socket?.close();
    _socket = null;
  }
}
