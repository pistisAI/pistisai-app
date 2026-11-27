import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';
import '../config/theme.dart';
import '../services/app_temp_files.dart';
import '../services/gui_automation_service.dart';

class GuiAutomationScreen extends StatefulWidget {
  const GuiAutomationScreen({super.key});

  @override
  State<GuiAutomationScreen> createState() => _GuiAutomationScreenState();
}

class _GuiAutomationScreenState extends State<GuiAutomationScreen> {
  final _service = GuiAutomationService();
  String _result = '';
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _service.initialize();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context).guiTitle),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/'),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          _service.isInitialized
                              ? Icons.check_circle
                              : Icons.warning,
                          color: _service.isInitialized
                              ? AppTheme.colorsOf(context).success
                              : AppTheme.colorsOf(context).warning,
                        ),
                        const SizedBox(width: 8),
                        Text(_service.status),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Quick Actions
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        ElevatedButton.icon(
                          onPressed: _isProcessing ? null : _takeScreenshot,
                          icon: const Icon(Icons.camera_alt),
                          label:
                              Text(AppLocalizations.of(context).guiScreenshot),
                        ),
                        ElevatedButton.icon(
                          onPressed: _isProcessing ? null : _runAnalysis,
                          icon: const Icon(Icons.analytics),
                          label: Text(AppLocalizations.of(context).guiAnalyze),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Running actions from this screen is not wired to the approval
            // gate, so it is not offered (#861).
            Card(
              child: ListTile(
                leading: const Icon(Icons.block),
                title: Text(AppLocalizations.of(context).guiActionsUnavailable),
              ),
            ),

            const SizedBox(height: 16),

            // Results
            if (_result.isNotEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppLocalizations.of(context).guiResult,
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      SelectableText(_result),
                    ],
                  ),
                ),
              ),

            const Spacer(),

            // Info Footer
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color:
                    AppTheme.colorsOf(context).secondary.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.info, size: 16),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      AppLocalizations.of(context).guiLocalRuntime,
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _takeScreenshot() async {
    final l10n = AppLocalizations.of(context);
    final path = await _service.takeScreenshot();
    if (path != null) {
      setState(() {
        _result = l10n.guiScreenshotSaved(path);
      });
    }
  }

  Future<void> _runAnalysis() async {
    setState(() => _isProcessing = true);
    final screenshotPath = await _service.takeScreenshot();
    if (screenshotPath != null) {
      final result = await _service.analyzeScreenshot(screenshotPath);
      // The screenshot was only needed for this analysis.
      await AppTempFiles.deleteQuietly(screenshotPath);
      setState(() => _result = result);
    }
    setState(() => _isProcessing = false);
  }
}
