/// Whether the computer the app runs on can host a local model (#1077).
///
/// AGENTS.md wording: the app runs on the client's computer if it has enough
/// hardware; otherwise on a local machine we provide. This file holds the
/// result type, the thresholds and the pure decision rule. Detection lives in
/// `hardware_probe.dart`; nothing here touches the network or the platform.
library;

/// The three answers the capability check can give.
enum LocalModelCapability {
  /// This machine can host a local model.
  sufficient,

  /// This machine should use a provided local machine to host the model.
  insufficient,

  /// Detection is unavailable on this platform, or it did not return a result.
  unknown,
}

/// Why the check returned its [LocalModelCapability]. The UI and setup logic
/// read this instead of re-deriving the rule.
enum LocalModelCapabilityReason {
  /// Web, mobile or another platform without a hardware probe.
  unsupportedPlatform,

  /// The probe ran but could not read the total memory.
  probeFailed,

  /// The processor architecture is not one local model runtimes ship for.
  unsupportedArchitecture,

  /// Total memory is below [LocalModelThresholds.minimumTotalMemoryGiB].
  belowMinimumMemory,

  /// Total memory is in the middle zone and nothing else qualifies it.
  middleZoneMemory,

  /// Total memory is in the middle zone and a local provider is running.
  middleZoneWithLocalProvider,

  /// Total memory is in the middle zone and the GPU has enough video memory.
  middleZoneWithGpu,

  /// Total memory meets [LocalModelThresholds.recommendedTotalMemoryGiB].
  meetsRecommendedMemory,

  /// Memory could not be read, but a local provider is already running here.
  localProviderReachable,
}

/// Thresholds for the capability check, kept in one place.
///
/// These values are provisional and conservative; the product owner has to
/// confirm them (#1077). They target a small quantised chat model (about
/// 7-8B parameters at 4-bit) plus the operating system and the app.
///
/// * `sufficient`: at least [recommendedTotalMemoryGiB] of total memory.
/// * `insufficient`: below [minimumTotalMemoryGiB] of total memory.
/// * Middle zone (between the two): `insufficient`, unless a local model
///   provider (Ollama / LM Studio) is already reachable on this computer, or
///   a GPU reports at least [middleZoneMinimumGpuMemoryGiB] of video memory.
///
/// Machines sold as "16 GB" usually report a little less (firmware and
/// integrated graphics reserve some), so totals are compared against
/// `nominal * reportedMemoryTolerance`.
class LocalModelThresholds {
  const LocalModelThresholds._();

  /// Total memory at or above which this machine is `sufficient`.
  static const int recommendedTotalMemoryGiB = 16;

  /// Total memory below which this machine is `insufficient`.
  static const int minimumTotalMemoryGiB = 8;

  /// Dedicated GPU memory that qualifies a middle-zone machine.
  static const int middleZoneMinimumGpuMemoryGiB = 8;

  /// Share of the nominal size a machine must report to count as that size.
  static const double reportedMemoryTolerance = 0.9;

  /// Architectures local model runtimes publish builds for (lower case, as
  /// returned by `uname -m` or `PROCESSOR_ARCHITECTURE`).
  static const Set<String> supportedArchitectures = {
    'x86_64',
    'amd64',
    'x64',
    'arm64',
    'aarch64',
  };

  static const int bytesPerGiB = 1024 * 1024 * 1024;

  static int get recommendedTotalMemoryBytes =>
      (recommendedTotalMemoryGiB * bytesPerGiB * reportedMemoryTolerance)
          .floor();

  static int get minimumTotalMemoryBytes =>
      (minimumTotalMemoryGiB * bytesPerGiB * reportedMemoryTolerance).floor();

  static int get middleZoneMinimumGpuMemoryBytes =>
      (middleZoneMinimumGpuMemoryGiB * bytesPerGiB * reportedMemoryTolerance)
          .floor();
}

/// Raw hardware signals read from this computer. Any field may be null when
/// the platform did not report it.
class HardwareSnapshot {
  const HardwareSnapshot({
    this.architecture,
    this.totalMemoryBytes,
    this.availableMemoryBytes,
    this.gpuName,
    this.gpuMemoryBytes,
  });

  /// Normalised to lower case, e.g. `x86_64`, `arm64`.
  final String? architecture;
  final int? totalMemoryBytes;
  final int? availableMemoryBytes;
  final String? gpuName;

  /// Dedicated video memory, when cheaply detectable (NVIDIA only today).
  final int? gpuMemoryBytes;

  @override
  String toString() => 'HardwareSnapshot(arch: $architecture, '
      'total: $totalMemoryBytes, available: $availableMemoryBytes, '
      'gpu: $gpuName, gpuMemory: $gpuMemoryBytes)';
}

/// The answer of the capability check, with the signals that produced it.
class LocalModelCapabilityResult {
  const LocalModelCapabilityResult({
    required this.capability,
    required this.reason,
    this.snapshot,
    this.localProviderNames = const [],
  });

  final LocalModelCapability capability;
  final LocalModelCapabilityReason reason;

  /// Null when no probe exists for this platform.
  final HardwareSnapshot? snapshot;

  /// Names of local model providers found reachable on loopback.
  final List<String> localProviderNames;

  bool get localProviderReachable => localProviderNames.isNotEmpty;

  bool get isSufficient => capability == LocalModelCapability.sufficient;

  static const LocalModelCapabilityResult unsupportedPlatform =
      LocalModelCapabilityResult(
    capability: LocalModelCapability.unknown,
    reason: LocalModelCapabilityReason.unsupportedPlatform,
  );

  @override
  String toString() =>
      'LocalModelCapabilityResult(${capability.name}, ${reason.name}, '
      '$snapshot, providers: $localProviderNames)';
}

/// The decision rule. Pure: same inputs, same answer.
///
/// [snapshot] is null when the platform has no probe (web, mobile).
LocalModelCapabilityResult evaluateLocalModelCapability({
  required HardwareSnapshot? snapshot,
  List<String> localProviderNames = const [],
}) {
  if (snapshot == null) {
    return LocalModelCapabilityResult(
      capability: LocalModelCapability.unknown,
      reason: LocalModelCapabilityReason.unsupportedPlatform,
      localProviderNames: localProviderNames,
    );
  }

  LocalModelCapabilityResult result(
    LocalModelCapability capability,
    LocalModelCapabilityReason reason,
  ) =>
      LocalModelCapabilityResult(
        capability: capability,
        reason: reason,
        snapshot: snapshot,
        localProviderNames: localProviderNames,
      );

  final arch = snapshot.architecture;
  if (arch != null &&
      !LocalModelThresholds.supportedArchitectures.contains(arch)) {
    return result(
      LocalModelCapability.insufficient,
      LocalModelCapabilityReason.unsupportedArchitecture,
    );
  }

  final providerReachable = localProviderNames.isNotEmpty;
  final total = snapshot.totalMemoryBytes;
  if (total == null || total <= 0) {
    return providerReachable
        ? result(
            LocalModelCapability.sufficient,
            LocalModelCapabilityReason.localProviderReachable,
          )
        : result(
            LocalModelCapability.unknown,
            LocalModelCapabilityReason.probeFailed,
          );
  }

  if (total < LocalModelThresholds.minimumTotalMemoryBytes) {
    return result(
      LocalModelCapability.insufficient,
      LocalModelCapabilityReason.belowMinimumMemory,
    );
  }

  if (total >= LocalModelThresholds.recommendedTotalMemoryBytes) {
    return result(
      LocalModelCapability.sufficient,
      LocalModelCapabilityReason.meetsRecommendedMemory,
    );
  }

  // Middle zone.
  if (providerReachable) {
    return result(
      LocalModelCapability.sufficient,
      LocalModelCapabilityReason.middleZoneWithLocalProvider,
    );
  }
  final gpuMemory = snapshot.gpuMemoryBytes;
  if (gpuMemory != null &&
      gpuMemory >= LocalModelThresholds.middleZoneMinimumGpuMemoryBytes) {
    return result(
      LocalModelCapability.sufficient,
      LocalModelCapabilityReason.middleZoneWithGpu,
    );
  }
  return result(
    LocalModelCapability.insufficient,
    LocalModelCapabilityReason.middleZoneMemory,
  );
}
