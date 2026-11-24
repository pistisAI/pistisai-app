import 'package:flutter/material.dart';

import '../../config/theme.dart';
import '../../l10n/app_localizations.dart';
import '../../services/agent_runtime/agent_runtime_client.dart';

/// Tools shown in the chat "Tools" sheet (#860).
enum ChatTool { desktop, vision, voice, webSearch, code }

/// Whether the connected agent can use a [ChatTool] right now.
enum ChatToolState {
  /// The agent is connected and its runtime reports this capability.
  available,

  /// No agent runtime is connected, so no tool can run.
  needsAgent,

  /// An agent is connected but its runtime does not report this capability.
  notReported,
}

/// One row of the tools sheet.
class ChatToolStatus {
  const ChatToolStatus(this.tool, this.state);

  final ChatTool tool;
  final ChatToolState state;

  bool get isAvailable => state == ChatToolState.available;
}

/// Derives tool availability from the live connection and the capability
/// manifest of the active agent runtime. Nothing is marked available unless
/// an agent is connected and reports the matching capability.
List<ChatToolStatus> deriveChatTools({
  required bool agentConnected,
  RuntimeCapabilityManifest? capabilities,
}) {
  ChatToolState stateFor(bool reported) {
    if (!agentConnected || capabilities == null) {
      return ChatToolState.needsAgent;
    }
    return reported ? ChatToolState.available : ChatToolState.notReported;
  }

  final caps = capabilities;
  return [
    ChatToolStatus(
        ChatTool.desktop, stateFor(caps?.desktopActionRequests ?? false)),
    ChatToolStatus(
        ChatTool.vision, stateFor(caps?.desktopActionRequests ?? false)),
    ChatToolStatus(ChatTool.voice, stateFor(caps?.voice ?? false)),
    ChatToolStatus(ChatTool.webSearch, stateFor(caps?.toolRequests ?? false)),
    ChatToolStatus(ChatTool.code, stateFor(caps?.toolRequests ?? false)),
  ];
}

/// Bottom sheet listing what the connected agent can do.
class ChatToolsPanel extends StatelessWidget {
  const ChatToolsPanel({
    super.key,
    required this.agentName,
    required this.tools,
  });

  final String agentName;
  final List<ChatToolStatus> tools;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.handyman,
                    size: 24, color: AppTheme.colorsOf(context).warning),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    l10n.homeToolsTitle(agentName),
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              l10n.homeToolsSubtitle,
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppTheme.colorsOf(context).textColorLight,
              ),
            ),
            const SizedBox(height: 20),
            for (final status in tools) _ToolRow(status: status),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _ToolRow extends StatelessWidget {
  const _ToolRow({required this.status});

  final ChatToolStatus status;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = AppTheme.colorsOf(context);
    final available = status.isAvailable;
    final (IconData icon, String title, String description) =
        switch (status.tool) {
      ChatTool.desktop => (
          Icons.desktop_windows,
          l10n.homeToolDesktop,
          l10n.homeToolDesktopDescription,
        ),
      ChatTool.vision => (
          Icons.visibility,
          l10n.homeToolVision,
          l10n.homeToolVisionDescription,
        ),
      ChatTool.voice => (
          Icons.record_voice_over,
          l10n.homeToolVoice,
          l10n.homeToolVoiceDescription,
        ),
      ChatTool.webSearch => (
          Icons.language,
          l10n.homeToolWebSearch,
          l10n.homeToolWebSearchDescription,
        ),
      ChatTool.code => (
          Icons.code,
          l10n.homeToolCode,
          l10n.homeToolCodeDescription,
        ),
    };
    final String? note = switch (status.state) {
      ChatToolState.available => null,
      ChatToolState.needsAgent => l10n.homeToolRequiresAgent,
      ChatToolState.notReported => l10n.homeToolNotReported,
    };
    final accent = available ? colors.success : colors.textColorLight;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 22, color: accent),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        title,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: (available ? colors.success : colors.warning)
                            .withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        available
                            ? l10n.homeToolAvailable
                            : l10n.homeToolUnavailable,
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: available ? colors.success : colors.warning,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 12,
                    color: colors.textColorLight.withValues(alpha: 0.6),
                  ),
                ),
                if (note != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      note,
                      style: TextStyle(
                        fontSize: 10,
                        color: colors.warning.withValues(alpha: 0.6),
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (available)
            Icon(
              Icons.check_circle,
              size: 18,
              color: colors.success.withValues(alpha: 0.8),
            ),
        ],
      ),
    );
  }
}
