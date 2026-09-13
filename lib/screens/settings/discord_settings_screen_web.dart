import 'package:flutter/material.dart';
import '../../config/theme.dart';

/// Web stub for Discord settings - Discord bot integration is desktop-only
/// (requires dart:ffi via nyxx, not available on web).
class DiscordSettingsScreen extends StatelessWidget {
  const DiscordSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Discord Bot Settings'),
      ),
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.discord,
                size: 64,
                color: AppTheme.colorsOf(context).primary,
              ),
              SizedBox(height: 24),
              Text(
                'Discord Bot Settings',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 16),
              Text(
                'Discord bot integration is only available on the desktop app. '
                'This feature requires native FFI bindings (via nyxx) '
                'that are not supported on the web platform.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: AppTheme.colorsOf(context).textColorLight),
              ),
              SizedBox(height: 24),
              Text(
                'Please use the desktop version of Pistisai to configure '
                'your Discord bot.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: AppTheme.colorsOf(context).textColorLight),
              ),
            ],
          ),
        ),
      ),
    );
  }
}