import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../config/theme.dart';
import '../../models/chat_model.dart';
import '../../services/streaming_chat_service.dart';
import '../../services/connection_manager_service.dart';
import '../../components/message_bubble.dart';
import '../../components/message_input.dart' as msg_input;
import '../../components/glass_container.dart';
import '../../components/welcome_screen.dart';
import '../../components/animated_background.dart';
import '../../features/avatar/avatar_widget.dart';
import '../../models/avatar/personality_models.dart';
import '../../di/locator.dart' as di;
import '../../services/avatar/personality_engine.dart';

/// Main layout — clean chat interface, nothing else.
class HomeLayout extends StatefulWidget {
  const HomeLayout({
    super.key,
    required this.isCompact,
    required this.scrollController,
    required this.onSendMessage,
  });

  final bool isCompact;
  final ScrollController scrollController;
  final void Function(StreamingChatService service, String message)
      onSendMessage;

  @override
  State<HomeLayout> createState() => _HomeLayoutState();
}

class _HomeLayoutState extends State<HomeLayout> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final body = Stack(
      children: [
        const Positioned.fill(child: AnimatedBackground()),
        _ChatPane(
          isCompact: widget.isCompact,
          scrollController: widget.scrollController,
          onSendMessage: widget.onSendMessage,
        ),
      ],
    );

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: body,
    );
  }
}

class _ChatPane extends StatefulWidget {
  const _ChatPane({
    required this.isCompact,
    required this.scrollController,
    required this.onSendMessage,
  });

  final bool isCompact;
  final ScrollController scrollController;
  final void Function(StreamingChatService service, String message)
      onSendMessage;

  @override
  State<_ChatPane> createState() => _ChatPaneState();
}

class _ChatPaneState extends State<_ChatPane> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _ensureChannelExists();
      _autoConnectRuntime();
    });
  }

  void _ensureChannelExists() {
    try {
      final chatService = context.read<StreamingChatService>();
      if (chatService.currentConversation == null) {
        chatService.resetContext();
      }
    } catch (_) {
      // StreamingChatService not registered on this platform (web).
    }
  }

  /// After wizard completion, the connection manager may have a backend
  /// configured but _isConnected still false.  Trigger a connection test
  /// so the UI shows "Runtime channel ready" without manual intervention.
  void _autoConnectRuntime() {
    try {
      final cm = context.read<ConnectionManagerService>();
      if (!cm.isConnected && cm.currentBackend != null) {
        cm.testConnection();
      }
    } catch (_) {
      // ConnectionManagerService not available on this platform.
    }
  }

  Widget _buildHeader(BuildContext context) {
    final theme = Theme.of(context);
    final spacing = AppTheme.spacingOf(context);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: spacing.l,
        vertical: spacing.m,
      ),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor.withValues(alpha: 0.2),
        border: Border(
          bottom: BorderSide(
            color: theme.dividerColor.withValues(alpha: 0.1),
            width: 1,
          ),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Image.asset(
                  'assets/images/app_icon.png',
                  width: 28,
                  height: 28,
                  errorBuilder: (ctx, _, __) => const Icon(
                    Icons.hub_outlined,
                    size: 28,
                    color: Colors.amber,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'Pistisai',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
            IconButton(
              icon: const Icon(Icons.settings_outlined),
              onPressed: () => context.go('/config'),
              tooltip: 'Settings',
              style: IconButton.styleFrom(
                hoverColor: theme.colorScheme.primary.withValues(alpha: 0.1),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConnectionWarning(BuildContext context) {
    final theme = Theme.of(context);
    final spacing = AppTheme.spacingOf(context);

    return Container(
      margin: EdgeInsets.all(spacing.m),
      child: GlassContainer(
        borderRadius: 16,
        blur: 15,
        border: Border.all(
          color: Colors.amber.withValues(alpha: 0.2),
          width: 1,
        ),
        padding: EdgeInsets.all(spacing.m),
        child: Row(
          children: [
            const Icon(
              Icons.warning_amber_rounded,
              color: Colors.amber,
              size: 24,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'No Local Agent Connected',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.amber,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'To orchestrate local models and enable desktop controls, please download and run the companion app.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            ElevatedButton.icon(
              onPressed: () => context.go('/download'),
              icon: const Icon(Icons.download_rounded, size: 16),
              label: const Text('Download App'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber,
                foregroundColor: Colors.black87,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                textStyle: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStandaloneWarning(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        constraints: const BoxConstraints(maxWidth: 500),
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Beautiful glowing warning icon container
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.amber.withValues(alpha: 0.15),
                      blurRadius: 40,
                      spreadRadius: 8,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.warning_amber_rounded,
                  size: 72,
                  color: Colors.amber,
                ),
              ),
              const SizedBox(height: 28),
              Text(
                'No Agent Connected',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colors.onSurface,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'Pistisai requires the desktop companion app to connect to your local agent runtimes (Hermes, OpenClaw, etc.) and orchestrate secure desktop capabilities.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colors.onSurface.withValues(alpha: 0.7),
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              // Download CTA
              ElevatedButton.icon(
                onPressed: () => context.go('/download'),
                icon: const Icon(Icons.download_rounded),
                label: const Text('Download Companion App'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber,
                  foregroundColor: Colors.black87,
                  elevation: 2,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  textStyle: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Secondary manual setting option
              TextButton.icon(
                onPressed: () => context.go('/config'),
                icon: const Icon(Icons.settings_outlined, size: 18),
                label: const Text('Configure connection manually'),
                style: TextButton.styleFrom(
                  foregroundColor: colors.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Guard against missing providers on platforms where services aren't registered
    try {
      return Consumer2<StreamingChatService, ConnectionManagerService>(
        builder: (context, chatService, connectionManager, child) {
          final conversation = chatService.currentConversation;
          final spacing = AppTheme.spacingOf(context);
          final hasMessages = conversation != null && conversation.messages.isNotEmpty;

          return Column(
            children: [
              _buildHeader(context),
              if (!connectionManager.isConnected && hasMessages)
                _buildConnectionWarning(context),
              Expanded(
                child: hasMessages
                    ? _MessageList(
                        conversation: conversation,
                        controller: widget.scrollController,
                      )
                    : (!connectionManager.isConnected
                        ? _buildStandaloneWarning(context)
                        : WelcomeScreen(
                            onNewChat: () => chatService.resetContext(),
                            onAction: (message) =>
                                widget.onSendMessage(chatService, message),
                          )),
              ),
              if (connectionManager.isConnected || hasMessages) ...[
                // 5-pillar action bar
                _ActionBar(isConnected: connectionManager.isConnected),
                GlassContainer(
                  margin: EdgeInsets.only(
                    bottom: widget.isCompact ? spacing.m : spacing.l,
                    left: spacing.m,
                    right: spacing.m,
                  ),
                  borderRadius: 24,
                  blur: 20,
                  child: msg_input.MessageInput(
                    onSendMessage: (message) =>
                        widget.onSendMessage(chatService, message),
                    isLoading: chatService.isLoading,
                    placeholder: 'Message Hermes...',
                  ),
                ),
              ],
            ],
          );
        },
      );
    } catch (_) {
      return Column(
        children: [
          _buildHeader(context),
          Expanded(
            child: _buildStandaloneWarning(context),
          ),
        ],
      );
    }
  }
}

class _MessageList extends StatelessWidget {
  const _MessageList({required this.conversation, required this.controller});

  final Conversation conversation;
  final ScrollController controller;

  @override
  Widget build(BuildContext context) {
    final spacing = AppTheme.spacingOf(context);
    final messages = conversation.messages.reversed.toList();

    return ListView.builder(
      controller: controller,
      reverse: true,
      padding: EdgeInsets.symmetric(vertical: spacing.m),
      itemCount: messages.length,
      itemBuilder: (context, index) {
        final message = messages[index];
        return MessageBubble(
          key: ValueKey(message.id),
          message: message,
          showAvatar: true,
          onRetry: message.hasError
              ? () {
                  final chatService = context.read<StreamingChatService>();
                  _retryMessage(chatService, message);
                }
              : null,
        );
      },
    );
  }

  static void _retryMessage(
    StreamingChatService chatService,
    Message errorMessage,
  ) {
    final conversation = chatService.currentConversation;
    if (conversation == null) return;

    String? lastUserMessage;
    final messages = conversation.messages;

    for (int i = messages.length - 1; i >= 0; i--) {
      final msg = messages[i];
      if (msg.id == errorMessage.id) {
        for (int j = i - 1; j >= 0; j--) {
          if (messages[j].role == MessageRole.user) {
            lastUserMessage = messages[j].content;
            break;
          }
        }
        break;
      }
    }

    if (lastUserMessage != null && lastUserMessage.isNotEmpty) {
      chatService.sendMessage(lastUserMessage);
    }
  }
}

/// Mini action bar for the 5 pillars — avatar, tools, mood, settings.
class _ActionBar extends StatelessWidget {
  final bool isConnected;

  const _ActionBar({required this.isConnected});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _PillarButton(
            icon: Icons.face_6,
            label: 'Avatar',
            enabled: isConnected,
            onTap: () => _openAvatar(context),
          ),
          _PillarButton(
            icon: Icons.handyman,
            label: 'Tools',
            enabled: isConnected,
            onTap: () => _showTools(context),
          ),
          _PillarButton(
            icon: Icons.favorite,
            label: 'Mood',
            enabled: isConnected,
            onTap: () => _showMood(context),
          ),
        ],
      ),
    );
  }

  void _openAvatar(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        content: Center(
          child: AgentAvatar(
            state: AgentState.idle,
            size: 200,
          ),
        ),
        actions: [
          Center(
            child: TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Close'),
            ),
          ),
        ],
      ),
    );
  }

  void _showTools(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => const _ToolsPanel(),
    );
  }

  void _showMood(BuildContext context) {
    final engine = di.serviceLocator<PersonalityEngine>();
    showDialog(
      context: context,
      builder: (ctx) => FutureBuilder<ExtendedAvatarProfile>(
        future: engine.getPersonality(),
        builder: (ctx, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const AlertDialog(
              content: Center(child: CircularProgressIndicator()),
            );
          }
          if (snapshot.hasError || !snapshot.hasData) {
            return AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.favorite, size: 24),
                  SizedBox(width: 8),
                  Text("Zoid's Mood"),
                ],
              ),
              content: const Text('Personality engine not ready yet.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Close'),
                ),
              ],
            );
          }
          final profile = snapshot.data!;
          final traits = profile.traits;
          return AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.favorite, size: 24),
                SizedBox(width: 8),
                Text("Zoid's Mood"),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Agent: ${profile.agentName}',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                _TraitBar('Formality', traits.formality),
                _TraitBar('Humor', traits.humor),
                _TraitBar('Enthusiasm', traits.enthusiasm),
                _TraitBar('Empathy', traits.empathy),
                const SizedBox(height: 8),
                Text('Evolution: ${profile.evolutionStage}',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Close'),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _TraitBar extends StatelessWidget {
  final String label;
  final double value;

  const _TraitBar(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: const TextStyle(fontSize: 13)),
              Text('${(value * 100).round()}%',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
            ],
          ),
          const SizedBox(height: 2),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: value,
              minHeight: 6,
              backgroundColor: Colors.grey.shade200,
            ),
          ),
        ],
      ),
    );
  }
}

class _PillarButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool enabled;
  final VoidCallback onTap;

  const _PillarButton({
    required this.icon,
    required this.label,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Opacity(
      opacity: enabled ? 1.0 : 0.4,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: enabled ? onTap : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 18, color: colors.primary),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: colors.onSurface.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Bottom sheet showing Zoid's available capabilities.
class _ToolsPanel extends StatelessWidget {
  const _ToolsPanel();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'What Zoid Can Do',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 20),
            _ToolRow(Icons.desktop_windows, 'Desktop Control', 'Click, type, scroll, drag on your PC'),
            _ToolRow(Icons.visibility, 'Vision', 'See and analyze your screen'),
            _ToolRow(Icons.record_voice_over, 'Voice', 'Speak and listen'),
            _ToolRow(Icons.language, 'Web Search', 'Search and extract web content'),
            _ToolRow(Icons.code, 'Code Execution', 'Run Python, shell, and Dart scripts'),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _ToolRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const _ToolRow(this.icon, this.title, this.description);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 24, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
                Text(description,
                    style: TextStyle(
                        fontSize: 12, color: Colors.grey.shade600)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
