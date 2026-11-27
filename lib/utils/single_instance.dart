import 'single_instance_stub.dart'
    if (dart.library.io) 'single_instance_io.dart';

/// Ensures only one instance of the app runs at a time.
///
/// Call [acquireLock] before [runApp]. Returns true if this is the first
/// instance, false if another instance is running.
class SingleInstance {
  /// Returns true if this is the first instance, false if another is running.
  ///
  /// The first instance passes [onForwardedUrl] the callback URLs a later
  /// launch forwards with [forwardToRunningInstance], when [accept] allows
  /// them.
  static Future<bool> acquireLock({
    void Function(String url)? onForwardedUrl,
    bool Function(String url)? accept,
  }) =>
      SingleInstanceImpl.acquireLock(
        onForwardedUrl: onForwardedUrl,
        accept: accept,
      );

  /// Hand [url] to the running instance (loopback only). Returns true when
  /// it was sent.
  static Future<bool> forwardToRunningInstance(String url) =>
      SingleInstanceImpl.forwardToRunningInstance(url);

  /// Releases the lock so a future instance can start.
  static Future<void> releaseLock() => SingleInstanceImpl.releaseLock();
}
