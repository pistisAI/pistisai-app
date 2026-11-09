/// Web no-op replacement for the camera_desktop plugin registration.
/// camera_desktop has no web implementation; the `camera` package handles
/// web natively, so registration is unnecessary here.
class CameraDesktopPlugin {
  static void registerWith() {}
}
