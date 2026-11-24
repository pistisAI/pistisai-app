library;

import 'package:flutter/material.dart';

import '../../services/popout/popout_manager.dart';

/// Placeholder for a future "pop out this section" button.
///
/// Pop-out windows are not available yet: [PopOutManager] only records state
/// in memory and no window is ever opened. Per AGENTS.md ("Controls tell the
/// truth"), the button renders nothing until a real multi-window
/// implementation exists (#858). Screens may keep the widget in their app bar
/// so the control reappears in one place once it is wired.
class PopOutButton extends StatelessWidget {
  /// Name of the section this button controls
  final String sectionName;

  /// Branch index for multiple instances of the same section
  final int branchIndex;

  /// Optional manager override (kept for API compatibility)
  final PopOutManager? manager;

  const PopOutButton({
    super.key,
    required this.sectionName,
    this.branchIndex = 0,
    this.manager,
  });

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
