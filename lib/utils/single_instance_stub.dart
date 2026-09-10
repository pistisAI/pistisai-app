/// Stub implementation for web (no-op — single-instance is desktop-only).
class SingleInstanceImpl {
  static Future<bool> acquireLock() async => true;
  static Future<void> releaseLock() async {}
}
