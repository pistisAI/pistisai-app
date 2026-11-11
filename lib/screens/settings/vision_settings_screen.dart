import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../l10n/app_localizations.dart';
import 'dart:io' show Platform;
import 'package:pistisai/di/locator.dart' as di;
import 'package:pistisai/services/vision/vision_service.dart';
import 'package:pistisai/services/vision/region_capture_service.dart';
import 'package:pistisai/services/vision/camera_capture_service.dart';
import 'package:pistisai/services/vision/v4l2_camera_service.dart';
import 'package:pistisai/screens/settings/v4l2_camera_preview.dart';
import 'package:pistisai/services/vision/ocr_engine_service.dart';

/// Vision Settings Screen
/// Provides UI for configuring and testing vision system services
class VisionSettingsScreen extends StatefulWidget {
  const VisionSettingsScreen({super.key});

  @override
  State<VisionSettingsScreen> createState() => _VisionSettingsScreenState();
}

class _VisionSettingsScreenState extends State<VisionSettingsScreen> {
  bool _isInitializing = false;
  String _statusMessage = '';
  final List<String> _testResults = [];

  // Get services from DI
  late final MainVisionService _mainVisionService =
      di.serviceLocator<MainVisionService>();
  late final RegionCaptureService _regionCaptureService =
      di.serviceLocator<RegionCaptureService>();
  late final CameraCaptureService _cameraCaptureService =
      di.serviceLocator<CameraCaptureService>();
  late final OcrEngineService _ocrEngineService =
      di.serviceLocator<OcrEngineService>();

  // Linux/v4l2 capture path — used on desktop Linux where the `camera`
  // plugin has no backend and camera_desktop can't convert YUYV frames.
  final V4L2CameraService _v4l2 = V4L2CameraService();
  bool _v4l2Running = false;

  Future<void> _startLinuxCamera(AppLocalizations l10n) async {
    try {
      await _v4l2.start();
      _v4l2Running = true;
      _testResults.add(l10n.visionLinuxCameraStarted(_v4l2.device));
    } catch (e) {
      _v4l2Running = false;
      _testResults.add(l10n.visionLinuxCameraError('$e'));
    }
    if (mounted) setState(() {});
  }

  Future<void> _initializeAllServices() async {
    // Read the strings before any await so no BuildContext is used across
    // an async gap.
    final l10n = AppLocalizations.of(context);
    setState(() {
      _isInitializing = true;
      _statusMessage = l10n.visionInitializing;
    });

    try {
      // Initialize Main Vision Service
      try {
        await _mainVisionService.initialize();
        _testResults.add(l10n.visionResultInitialized(l10n.visionMainService));
      } catch (e) {
        _testResults.add(l10n.visionResultError(l10n.visionMainService, '$e'));
      }

      // Initialize Region Capture Service
      try {
        await _regionCaptureService.initialize();
        _testResults
            .add(l10n.visionResultInitialized(l10n.visionRegionCaptureService));
      } catch (e) {
        _testResults
            .add(l10n.visionResultError(l10n.visionRegionCaptureService, '$e'));
      }

      // Initialize Camera Capture Service
      try {
        await _cameraCaptureService.initialize();
        _testResults
            .add(l10n.visionResultInitialized(l10n.visionCameraCaptureService));
      } catch (e) {
        _testResults
            .add(l10n.visionResultError(l10n.visionCameraCaptureService, '$e'));
      }

      // Initialize OCR Engine Service
      try {
        await _ocrEngineService.initialize();
        _testResults.add(l10n.visionResultInitialized(l10n.visionOcrService));
      } catch (e) {
        _testResults.add(l10n.visionResultError(l10n.visionOcrService, '$e'));
      }

      // On desktop Linux, start the v4l2 capture path (camera plugin has
      // no Linux backend; camera_desktop can't convert YUYV frames).
      if (Platform.isLinux) {
        await _startLinuxCamera(l10n);
      }

      setState(() {
        _statusMessage = l10n.visionInitComplete;
      });
    } catch (e) {
      setState(() {
        _statusMessage = l10n.visionInitFailed('$e');
        _testResults.add(l10n.visionFatalError('$e'));
      });
    } finally {
      setState(() {
        _isInitializing = false;
      });
    }
  }

  Widget _buildServiceStatusCard({
    required BuildContext context,
    required String title,
    required String icon,
    required bool isInitialized,
    String? lastError,
  }) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isInitialized
              ? Theme.of(context).colorScheme.primaryContainer
              : Theme.of(context).colorScheme.errorContainer,
          child: Text(icon),
        ),
        title: Text(title),
        subtitle: Text(
          isInitialized
              ? AppLocalizations.of(context).visionInitialized
              : (lastError ??
                  AppLocalizations.of(context).visionNotInitialized),
          style: TextStyle(
            color: isInitialized
                ? Theme.of(context).colorScheme.onPrimaryContainer
                : Theme.of(context).colorScheme.onErrorContainer,
          ),
        ),
        trailing: Icon(
          isInitialized ? Icons.check_circle : Icons.error,
          color: isInitialized
              ? AppTheme.colorsOf(context).success
              : AppTheme.colorsOf(context).danger,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.visionSettingsTitle),
      ),
      body: Column(
        children: [
          // Service Status Cards
          Expanded(
            child: ListView(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    l10n.visionServiceStatus,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                _buildServiceStatusCard(
                  context: context,
                  title: l10n.visionMainService,
                  icon: '👁️',
                  isInitialized: _mainVisionService.isInitialized,
                  lastError: null,
                ),
                _buildServiceStatusCard(
                  context: context,
                  title: l10n.visionRegionCaptureService,
                  icon: '🖼️',
                  isInitialized: _regionCaptureService.isInitialized,
                  lastError: _regionCaptureService.lastError,
                ),
                _buildServiceStatusCard(
                  context: context,
                  title: l10n.visionCameraCaptureService,
                  icon: '📷',
                  isInitialized: _cameraCaptureService.isInitialized,
                  lastError: _cameraCaptureService.lastError,
                ),
                _buildServiceStatusCard(
                  context: context,
                  title: l10n.visionOcrService,
                  icon: '🔤',
                  isInitialized: _ocrEngineService.isInitialized,
                  lastError: _ocrEngineService.lastError,
                ),
                // Live camera preview (Linux/v4l2 path). The feed is rendered
                // locally from ffmpeg-captured RGBA frames; no frames are
                // retained or transmitted by this widget.
                if (_v4l2Running)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.visionCameraPreview,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: SizedBox(
                            height: 240,
                            child: V4L2CameraPreview(service: _v4l2),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          l10n.visionCameraPreviewNote,
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(
                                  color: AppTheme.colorsOf(context)
                                      .textColorLight),
                        ),
                      ],
                    ),
                  ),
                if (_testResults.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      l10n.visionTestResults,
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: _testResults
                              .map((result) => Padding(
                                    padding:
                                        const EdgeInsets.symmetric(vertical: 4),
                                    child: Text(result),
                                  ))
                              .toList(),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          // Bottom Action Area
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              boxShadow: [
                BoxShadow(
                  color: AppTheme.colorsOf(context)
                      .textColor
                      .withValues(alpha: 0.1),
                  blurRadius: 4,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_statusMessage.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Text(
                      _statusMessage,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ElevatedButton(
                  onPressed: _isInitializing ? null : _initializeAllServices,
                  child: _isInitializing
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(l10n.visionInitializeAll),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    // Services are managed by DI, don't dispose here
    super.dispose();
  }
}
