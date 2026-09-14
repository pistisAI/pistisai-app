/// System Hub Page - Stub Implementation
/// This page is not available as the Pistisai package dependencies are missing.
library;

import 'package:flutter/material.dart';
import '../../config/theme.dart';

class SystemHubPage extends StatefulWidget {
  const SystemHubPage({super.key});

  @override
  State<SystemHubPage> createState() => _SystemHubPageState();
}

class _SystemHubPageState extends State<SystemHubPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('System Hub'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.settings_applications,
              size: 64,
              color: AppTheme.colorsOf(context).textColorLight.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 16),
            Text(
              'System Hub is not available',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppTheme.colorsOf(context).textColorLight,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'System monitoring features require additional dependencies',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.colorsOf(context).textColorLight.withValues(alpha: 0.7),
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
