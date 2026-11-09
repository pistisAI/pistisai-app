import 'dart:io';

import 'package:pistisai/services/hermes/hermes_local_agent_api.dart';

/// Contents of the local Hermes `.env`, or null when it is not installed.
String? readHermesAgentEnvText() {
  final home = hermesHomeDirectory();
  if (home == null || home.isEmpty) {
    return null;
  }
  final file = File('$home${Platform.pathSeparator}.env');
  if (!file.existsSync()) {
    return null;
  }
  try {
    return file.readAsStringSync();
  } catch (_) {
    return null;
  }
}
