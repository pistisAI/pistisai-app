import 'package:flutter/material.dart';

import '../../../config/theme.dart';
import '../../../l10n/app_localizations.dart';
import '../../../services/hardware/hardware_capability_service.dart';

/// Shows whether this computer can host a local model (#1077).
///
/// Runs [HardwareCapabilityService.check] once and renders the answer. Each
/// state says what it means; `insufficient` points to a local machine we
/// provide, never to a cloud service.
class LocalModelCapabilityCard extends StatefulWidget {
  const LocalModelCapabilityCard({super.key, required this.service});

  final HardwareCapabilityService service;

  @override
  State<LocalModelCapabilityCard> createState() =>
      _LocalModelCapabilityCardState();
}

class _LocalModelCapabilityCardState extends State<LocalModelCapabilityCard> {
  late Future<LocalModelCapabilityResult> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.service.check();
  }

  @override
  void didUpdateWidget(covariant LocalModelCapabilityCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.service, widget.service)) {
      _future = widget.service.check();
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<LocalModelCapabilityResult>(
      future: _future,
      builder: (context, snapshot) {
        final result = snapshot.data;
        if (result == null) {
          return _Frame(
            key: const Key('local_model_capability_checking'),
            icon: Icons.memory,
            color: AppTheme.colorsOf(context).info,
            title: AppLocalizations.of(context).localModelCheckChecking,
          );
        }
        return _ResultView(result: result);
      },
    );
  }
}

class _ResultView extends StatelessWidget {
  const _ResultView({required this.result});

  final LocalModelCapabilityResult result;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = AppTheme.colorsOf(context);
    final detail = localModelCapabilityDetail(l10n, result);
    switch (result.capability) {
      case LocalModelCapability.sufficient:
        return _Frame(
          key: const Key('local_model_capability_sufficient'),
          icon: Icons.check_circle_outline,
          color: colors.success,
          title: l10n.localModelCheckSufficientTitle,
          body: l10n.localModelCheckSufficientBody,
          detail: detail,
        );
      case LocalModelCapability.insufficient:
        return _Frame(
          key: const Key('local_model_capability_insufficient'),
          icon: Icons.dns_outlined,
          color: colors.warning,
          title: l10n.localModelCheckInsufficientTitle,
          body: l10n.localModelCheckInsufficientBody,
          detail: detail,
        );
      case LocalModelCapability.unknown:
        return _Frame(
          key: const Key('local_model_capability_unknown'),
          icon: Icons.help_outline,
          color: colors.info,
          title: l10n.localModelCheckUnknownTitle,
          body: l10n.localModelCheckUnknownBody(
            LocalModelThresholds.recommendedTotalMemoryGiB,
          ),
          detail: detail,
        );
    }
  }
}

String _gib(int bytes) =>
    (bytes / LocalModelThresholds.bytesPerGiB).toStringAsFixed(1);

/// One sentence naming the signals behind [result].
String localModelCapabilityDetail(
  AppLocalizations l10n,
  LocalModelCapabilityResult result,
) {
  final snapshot = result.snapshot;
  final total = snapshot?.totalMemoryBytes;
  final memory = total == null ? '?' : _gib(total);
  final providers = result.localProviderNames.join(', ');
  switch (result.reason) {
    case LocalModelCapabilityReason.unsupportedPlatform:
      return l10n.localModelReasonUnsupportedPlatform;
    case LocalModelCapabilityReason.probeFailed:
      return l10n.localModelReasonProbeFailed;
    case LocalModelCapabilityReason.unsupportedArchitecture:
      return l10n.localModelReasonUnsupportedArchitecture(
        snapshot?.architecture ?? l10n.localModelArchitectureUnknown,
      );
    case LocalModelCapabilityReason.belowMinimumMemory:
      return l10n.localModelReasonBelowMinimum(
        memory,
        LocalModelThresholds.minimumTotalMemoryGiB,
        LocalModelThresholds.recommendedTotalMemoryGiB,
      );
    case LocalModelCapabilityReason.middleZoneMemory:
      return l10n.localModelReasonMiddleZone(
        memory,
        LocalModelThresholds.recommendedTotalMemoryGiB,
      );
    case LocalModelCapabilityReason.middleZoneWithLocalProvider:
      return l10n.localModelReasonMiddleZoneProvider(memory, providers);
    case LocalModelCapabilityReason.middleZoneWithGpu:
      final gpu = snapshot?.gpuMemoryBytes;
      return l10n.localModelReasonMiddleZoneGpu(
        memory,
        gpu == null ? '?' : _gib(gpu),
      );
    case LocalModelCapabilityReason.meetsRecommendedMemory:
      return l10n.localModelReasonMeetsRecommended(
        memory,
        snapshot?.architecture ?? l10n.localModelArchitectureUnknown,
      );
    case LocalModelCapabilityReason.localProviderReachable:
      return l10n.localModelReasonProviderReachable(providers);
  }
}

class _Frame extends StatelessWidget {
  const _Frame({
    super.key,
    required this.icon,
    required this.color,
    required this.title,
    this.body,
    this.detail,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String? body;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: textTheme.labelLarge?.copyWith(
                    color: color,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (body != null) ...[
                  const SizedBox(height: 4),
                  Text(body!, style: TextStyle(color: color, height: 1.35)),
                ],
                if (detail != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    detail!,
                    style: textTheme.bodySmall?.copyWith(
                      color: AppTheme.colorsOf(context).textColorLight,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
