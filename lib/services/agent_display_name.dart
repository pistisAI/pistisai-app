import '../di/locator.dart' as di;
import 'avatar/avatar_state_service.dart';
import 'hermes_agent_name_reader_stub.dart'
    if (dart.library.io) 'hermes_agent_name_reader_io.dart';

const String kDefaultAgentName = 'Agent';

const Set<String> kLegacyHardcodedAgentTitles = {
  'Zoid Maltek',
  'Zoid',
  'Zoidbot',
};

/// The companion name the user set in Avatar settings.
///
/// Falls back to [kDefaultAgentName] when the avatar service is not
/// registered (web) or the profile has not loaded yet.
/// Name of the Hermes agent this app is connected to.
///
/// Hermes stores it as `A2A_AGENT_NAME` in its `.env`. That value is used as
/// written, including when the config says `hermes`. The avatar profile name
/// is used only when Hermes has no name configured.
String connectedAgentDisplayName({String? hermesEnv}) {
  final text = hermesEnv ?? readHermesAgentEnvText();
  final fromHermes = text == null ? null : parseHermesAgentName(text);
  if (fromHermes != null && fromHermes.isNotEmpty) {
    return fromHermes;
  }
  return configuredAgentName();
}

/// `A2A_AGENT_NAME` from a Hermes `.env` file, or null when it is unset.
String? parseHermesAgentName(String envText) {
  for (final line in envText.split(RegExp(r'\r?\n'))) {
    final trimmed = line.trim();
    if (trimmed.isEmpty || trimmed.startsWith('#')) {
      continue;
    }
    const prefix = 'A2A_AGENT_NAME=';
    if (!trimmed.startsWith(prefix)) {
      continue;
    }
    var value = trimmed.substring(prefix.length).trim();
    if (value.length >= 2 &&
        ((value.startsWith('"') && value.endsWith('"')) ||
            (value.startsWith("'") && value.endsWith("'")))) {
      value = value.substring(1, value.length - 1).trim();
    }
    return value.isEmpty ? null : value;
  }
  return null;
}

String configuredAgentName() {
  try {
    if (!di.serviceLocator.isRegistered<AvatarStateService>()) {
      return kDefaultAgentName;
    }
    final name = di.serviceLocator<AvatarStateService>().agentName.trim();
    return name.isEmpty ? kDefaultAgentName : name;
  } catch (_) {
    return kDefaultAgentName;
  }
}

String agentPossessive(String name) {
  final trimmed = name.trim();
  if (trimmed.isEmpty) return "$kDefaultAgentName's";
  if (trimmed.toLowerCase().endsWith('s')) return "$trimmed'";
  return "$trimmed's";
}

bool isLegacyHardcodedAgentTitle(String title) =>
    kLegacyHardcodedAgentTitles.contains(title);
