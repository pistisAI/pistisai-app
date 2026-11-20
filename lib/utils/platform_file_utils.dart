// Desktop implementation for file utilities
class PlatformFileUtils {
  /// No-op: OAuth callback URLs (including auth codes) must not be written to
  /// a world-readable temp file. Deep-link handling uses the in-process URL.
  static Future<void> writeCallbackFile(String callbackUrl) async {}
}
