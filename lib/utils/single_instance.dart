import 'single_instance_stub.dart'
    if (dart.library.io) 'single_instance_io.dart';

/// Ensures only one instance of the app runs at a time.
///
/// Call [acquireLock] before [runApp]. Returns true if this is the first
/// instance, false if another instance is already running.
class SingleInstance {
  /// Returns true if this is the first instance, false if another is running.
  static Future<bool> acquireLock() => SingleInstanceImpl.acquireLock();

  /// Releases the lock so a future instance can start.
  static Future<void> releaseLock() => SingleInstanceImpl.releaseLock();
}
