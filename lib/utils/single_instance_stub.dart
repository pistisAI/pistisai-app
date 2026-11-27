/// Stub implementation for web (no-op — single-instance is desktop-only).
class SingleInstanceImpl {
  static Future<bool> acquireLock({
    void Function(String url)? onForwardedUrl,
    bool Function(String url)? accept,
  }) async =>
      true;
  static Future<bool> forwardToRunningInstance(String url) async => false;
  static Future<void> releaseLock() async {}
}
