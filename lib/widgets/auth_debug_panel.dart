import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../services/auth_logger.dart';
import '../config/theme.dart';

/// Debug panel for authentication logging
/// Only visible in debug mode and on web platform
class AuthDebugPanel extends StatefulWidget {
  const AuthDebugPanel({super.key});

  @override
  State<AuthDebugPanel> createState() => _AuthDebugPanelState();
}

class _AuthDebugPanelState extends State<AuthDebugPanel> {
  bool _isExpanded = false;
  List<String> _logs = [];

  @override
  void initState() {
    super.initState();
    _refreshLogs();
  }

  void _refreshLogs() {
    if (kIsWeb) {
      setState(() {
        _logs = AuthLogger.getLogs();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Only show in debug mode and on web
    if (!kDebugMode || !kIsWeb) {
      return const SizedBox.shrink();
    }

    return Positioned(
      top: 16,
      right: 16,
      child: Material(
        elevation: 8,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          constraints: BoxConstraints(
            maxWidth: _isExpanded ? 400 : 200,
            maxHeight: _isExpanded ? 500 : 60,
          ),
          decoration: BoxDecoration(
            color: AppTheme.colorsOf(context).backgroundCard,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.colorsOf(context).info, width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              GestureDetector(
                onTap: () {
                  setState(() {
                    _isExpanded = !_isExpanded;
                  });
                  if (_isExpanded) {
                    _refreshLogs();
                  }
                },
                child: Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.colorsOf(context).info.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(12),
                      topRight: Radius.circular(12),
                      bottomLeft:
                          _isExpanded ? Radius.zero : Radius.circular(12),
                      bottomRight:
                          _isExpanded ? Radius.zero : Radius.circular(12),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.bug_report, color: AppTheme.colorsOf(context).info, size: 16),
                      SizedBox(width: 8),
                      Text(
                        'Auth Debug',
                        style: TextStyle(
                          color: AppTheme.colorsOf(context).textColor,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(width: 8),
                      Icon(
                        _isExpanded ? Icons.expand_less : Icons.expand_more,
                        color: AppTheme.colorsOf(context).info,
                        size: 16,
                      ),
                    ],
                  ),
                ),
              ),

              // Content
              if (_isExpanded) ...[
                // Summary
                Container(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Logs: ${_logs.length}',
                        style: TextStyle(
                          color: AppTheme.colorsOf(context).textColorLight,
                          fontSize: 11,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Errors: ${_logs.where((l) => l.contains('[ERROR]')).length}',
                        style: TextStyle(color: AppTheme.colorsOf(context).danger, fontSize: 11),
                      ),
                    ],
                  ),
                ),

                // Action buttons
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () async {
                            final messenger = ScaffoldMessenger.of(context);
                            await AuthLogger.downloadLogs();
                            if (!mounted) return;
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text('Debug log downloaded'),
                                duration: Duration(seconds: 2),
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.colorsOf(context).info,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            textStyle: const TextStyle(fontSize: 10),
                          ),
                          child: const Text('Download'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            AuthLogger.clearLogs();
                            _refreshLogs();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Debug log cleared'),
                                duration: Duration(seconds: 2),
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.colorsOf(context).danger,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            textStyle: const TextStyle(fontSize: 10),
                          ),
                          child: const Text('Clear'),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 8),

                // Recent logs
                Expanded(
                  child: Container(
                    margin: EdgeInsets.all(12),
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.colorsOf(context).backgroundCard,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: AppTheme.colorsOf(context).textColorLight),
                    ),
                    child: ListView.builder(
                      itemCount: _logs.length > 10 ? 10 : _logs.length,
                      itemBuilder: (context, index) {
                        final log = _logs[
                            _logs.length - 1 - index]; // Show newest first

                        Color levelColor = AppTheme.colorsOf(context).textColorLight;
                        if (log.contains('[ERROR]')) {
                          levelColor = AppTheme.colorsOf(context).danger;
                        }
                        if (log.contains('[WARNING]')) {
                          levelColor = AppTheme.colorsOf(context).warning;
                        }
                        if (log.contains('[INFO]')) {
                          levelColor = AppTheme.colorsOf(context).info;
                        }
                        if (log.contains('[DEBUG]')) {
                          levelColor = AppTheme.colorsOf(context).textColorLight;
                        }

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                log,
                                style: TextStyle(
                                  color: levelColor,
                                  fontSize: 10,
                                ),
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),

                // Refresh button
                Container(
                  padding: EdgeInsets.all(12),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _refreshLogs,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.colorsOf(context).textColorLight,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        textStyle: const TextStyle(fontSize: 10),
                      ),
                      child: const Text('Refresh'),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
