import 'hardware_probe.dart';

/// Web and other platforms without `dart:io`: no probe, so the capability
/// check answers `unknown`.
PlatformHardwareProbe? createDefaultHardwareProbe() => null;
