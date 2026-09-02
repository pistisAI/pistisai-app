import '../di/locator.dart' as di;
import 'avatar/avatar_state_service.dart';

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
