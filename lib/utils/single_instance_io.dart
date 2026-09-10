import 'dart:io';

/// Desktop implementation using a loopback TCP socket.
///
/// If another instance is already listening on the port, the bind fails and
/// we know we're a duplicate. The socket stays open for the life of the
/// process — when the app exits, the OS releases it automatically.
class SingleInstanceImpl {
  static ServerSocket? _socket;

  /// A port unlikely to collide with common dev services.
  /// 27182 = digits of e, chosen to avoid 3000/8080/1337/etc.
  static const int _lockPort = 27182;

  static Future<bool> acquireLock() async {
    try {
      _socket = await ServerSocket.bind(
        InternetAddress.loopbackIPv4,
        _lockPort,
        shared: false,
      );
      return true;
    } on SocketException {
      return false;
    }
  }

  static Future<void> releaseLock() async {
    await _socket?.close();
    _socket = null;
  }
}
