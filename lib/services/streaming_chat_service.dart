import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:rxdart/rxdart.dart';
import '../models/agent_event.dart';
import '../models/conversation.dart';
import '../models/message.dart';
import '../models/streaming_message.dart';

import 'streaming_service.dart';
import 'hermes/hermes_session_transcript.dart';
import 'hermes/hermes_streaming_service.dart';
import 'streaming_content_update.dart';

import 'connection_manager_service.dart';
import 'conversation_storage_service.dart';
import 'auth_service.dart';
import '../brand/brand_copy.dart';
import 'agent_display_name.dart';
import 'avatar/avatar_state_service.dart';
import '../di/locator.dart' as di;
import '../utils/logger.dart';

/// User-facing chat error. Never include Dart exception types.
String userFacingChatError(Object error, {required bool isConnected}) {
  if (!isConnected) {
    return 'No agent runtime connected. Open Settings to configure Hermes or another gateway.';
  }
  final raw = error.toString();
  if (error is TimeoutException || raw.contains('TimeoutException')) {
    return 'The agent did not respond in time. Check that your runtime is running and try again.';
  }
  return 'The agent could not complete that request. Check Settings and try again.';
}

/// Enhanced chat service with real-time streaming support
///
/// Provides progressive message streaming, real-time UI updates,
/// and integration with the tunnel manager for connection routing.
class StreamingChatService extends ChangeNotifier {
  final ConnectionManagerService _connectionManager;
  final ConversationStorageService _storageService;

  StreamingChatService(
    this._connectionManager,
    AuthService authService,
  ) : _storageService = ConversationStorageService(authService: authService) {
    _initializeService();
    _bindAgentNameListener();
  }

  /// The one conversation for this harness. Every connected device uses the
  /// same `pistisai` session id and loads the transcript from the harness.
  Conversation? _mainChannel;
  Timer? _sharedChannelTimer;
  bool _syncingSharedChannel = false;
  String? _channelSyncError;
  AvatarStateService? _avatarState;

  String? _selectedModel;
  bool _isLoading = false;
  bool _isStreaming = false;
  bool _storageReady = false;

  // Streaming state
  final BehaviorSubject<String> _streamingContentSubject =
      BehaviorSubject<String>.seeded('');
  final BehaviorSubject<String> _streamingReasoningSubject =
      BehaviorSubject<String>.seeded('');
  StreamSubscription<StreamingMessage>? _currentStreamSubscription;
  String _currentStreamingMessageId = '';

  /// Fallback: if no message.delta events were emitted but run.completed
  /// had output, store it here so _handleStreamingComplete can use it.
  String _runCompletedOutput = '';

  // Agent event state (tool calls, lifecycle)
  StreamSubscription<AgentEvent>? _agentEventSubscription;
  final List<ToolCall> _activeToolCalls = [];
  final List<ToolCall> _completedToolCalls = [];
  bool _isAgentRunning = false;

  // Getters
  Conversation? get currentConversation => _mainChannel;
  String? get selectedModel => _selectedModel;
  bool get isLoading => _isLoading;
  bool get isStreaming => _isStreaming;
  bool get hasConversations => _mainChannel != null;
  bool get isStorageReady => _storageReady;

  /// Set when the last shared-channel sync failed (fetch returned null).
  /// Cleared after a successful sync. Surfaced in the chat header.
  String? get channelSyncError => _channelSyncError;

  /// Stream of current streaming content for real-time UI updates
  Stream<String> get streamingContentStream => _streamingContentSubject.stream;

  /// Stream of current streaming reasoning for real-time UI updates
  Stream<String> get streamingReasoningStream =>
      _streamingReasoningSubject.stream;

  /// Whether the agent is currently running a tool.
  bool get isAgentRunning => _isAgentRunning;

  /// Tool calls currently in progress.
  List<ToolCall> get activeToolCalls => List.unmodifiable(_activeToolCalls);

  /// Tool calls that completed during this streaming session.
  List<ToolCall> get completedToolCalls =>
      List.unmodifiable(_completedToolCalls);

  /// All tool calls (active + completed) for this streaming session.
  List<ToolCall> get allToolCalls => [
        ..._completedToolCalls,
        ..._activeToolCalls,
      ];

  /// Initialize the service
  void _initializeService() {
    // Initialize storage service and load conversations
    _initializeStorage();

    // Listen to connection manager changes
    _connectionManager.addListener(_onConnectionManagerChanged);
  }

  /// Initialize storage service and load conversations
  Future<void> _initializeStorage() async {
    try {
      await _storageService.initialize();
      await _loadConversations();
      _startSharedChannelSync();
      appLogger.debug('[StreamingChat] Storage service initialized');
    } catch (e) {
      appLogger.error('[StreamingChat] Failed to initialize storage', error: e);
      // Fall back to in-memory conversations
      await _loadConversations();
    }
  }

  /// Handle connection manager changes
  void _onConnectionManagerChanged() {
    // Update available models when connections change
    final availableModels = _connectionManager.availableModels;
    if (availableModels.isNotEmpty) {
      // Auto-select first model if none selected
      if (_selectedModel == null) {
        _selectedModel = availableModels.first;
        appLogger.debug('[StreamingChat] Auto-selected model: $_selectedModel');
        notifyListeners();
      }
    }
    unawaited(_syncSharedChannel());
  }

  /// Load the main channel from storage
  Future<void> _loadConversations() async {
    try {
      final loaded = await _storageService.loadConversations();

      if (loaded.isNotEmpty) {
        // Prefer the pistisai platform channel; ignore leftover main-channel
        // api_server test sessions so we never poll that harness id again.
        Conversation? existing;
        for (final conversation in loaded) {
          if (conversation.id == Conversation.pistisaiChannelId) {
            existing = conversation;
            break;
          }
        }
        if (existing != null) {
          _mainChannel = existing;
          _applyAgentNameToMainChannel();
          appLogger.info(
            '[StreamingChat] Loaded pistisai channel '
            '(${existing.messages.length} messages)',
          );
        } else {
          appLogger.info(
            '[StreamingChat] No pistisai channel in storage — creating fresh '
            '(ignoring legacy main-channel if present)',
          );
          _createWelcomeConversation();
        }
      } else {
        _createWelcomeConversation();
      }
    } catch (e) {
      appLogger.error('[StreamingChat] Error loading conversations', error: e);
      _createWelcomeConversation();
    }

    _storageReady = true;
    notifyListeners();
    unawaited(_syncSharedChannel());
  }

  void _startSharedChannelSync() {
    _sharedChannelTimer ??= Timer.periodic(const Duration(seconds: 8), (_) {
      unawaited(_syncSharedChannel());
    });
  }

  /// Replace the on-screen thread with the harness transcript so every
  /// device shows the same conversation.
  Future<void> _syncSharedChannel() async {
    // A send is in flight until its stream completes/errors. sendMessage()
    // clears _isStreaming in its finally block right after subscribing, so
    // also gate on the placeholder id; otherwise a harness merge drops the
    // just-sent user row / Thinking placeholder mid-turn.
    if (_isStreaming ||
        _currentStreamingMessageId.isNotEmpty ||
        _syncingSharedChannel ||
        _mainChannel == null) {
      return;
    }
    final service = _getStreamingService();
    if (service is! HermesStreamingService) return;

    _syncingSharedChannel = true;
    try {
      final harness = await service.fetchSessionMessages(_mainChannel!.id);
      if (harness == null ||
          _mainChannel == null ||
          _isStreaming ||
          _currentStreamingMessageId.isNotEmpty) {
        if (harness == null && _mainChannel != null) {
          _setChannelSyncError(
            'Could not reach the hub transcript — check your connection.',
          );
        }
        return;
      }
      _setChannelSyncError(null);
      final merged = mergeHarnessTranscript(
        local: _mainChannel!.messages,
        harness: harness,
      );
      if (_sameMessages(merged, _mainChannel!.messages)) return;
      _mainChannel = _mainChannel!.copyWith(
        messages: merged,
        updatedAt: DateTime.now(),
      );
      _applyAgentNameToMainChannel(persist: false);
      await _saveConversationsAsync();
      notifyListeners();
    } finally {
      _syncingSharedChannel = false;
    }
  }

  void _setChannelSyncError(String? error) {
    if (_channelSyncError == error) return;
    _channelSyncError = error;
    notifyListeners();
  }

  bool _sameMessages(List<Message> left, List<Message> right) {
    if (left.length != right.length) return false;
    for (var i = 0; i < left.length; i++) {
      if (left[i].id != right[i].id || left[i].content != right[i].content) {
        return false;
      }
    }
    return true;
  }

  /// Create a welcome conversation when no conversations exist
  void _createWelcomeConversation() {
    // Ensure we have a model selected before creating conversation
    final availableModels = _connectionManager.availableModels;
    final modelToUse = _selectedModel ??
        (availableModels.isNotEmpty ? availableModels.first : 'default');

    // Update selected model if it was null
    if (_selectedModel == null && availableModels.isNotEmpty) {
      _selectedModel = availableModels.first;
      appLogger.debug(
        '[StreamingChat] Auto-selected model for welcome conversation: $_selectedModel',
      );
    }

    _mainChannel = Conversation.mainChannel(
      model: modelToUse,
      agentName: configuredAgentName(),
    );

    final welcomeMessage = Message.system(
      content: BrandCopy.chatWelcome,
    );

    _mainChannel = _mainChannel!.addMessage(welcomeMessage);

    // Save the welcome conversation
    _saveConversations();
  }

  /// Save main channel to storage
  void _saveConversations() {
    _saveConversationsAsync().catchError((e) {
      appLogger.error('[StreamingChat] Error saving conversations', error: e);
    });
  }

  Future<void> _saveConversationsAsync() async {
    if (_mainChannel == null) return;
    await _storageService.saveConversations([_mainChannel!]);
    appLogger.info(
      '[StreamingChat] Main channel saved (${_mainChannel!.messages.length} messages)',
    );
  }

  /// Stay on the shared harness conversation.
  ///
  /// `/new` and `/reset` used to clear this device's copy. That made each
  /// device look like it had its own chat. The harness session is the
  /// conversation, so these commands reload it instead of starting another.
  void resetContext() {
    unawaited(_syncSharedChannel());
  }

  /// Update conversation title
  void updateConversationTitle(Conversation conversation, String newTitle) {
    if (_mainChannel == null || _mainChannel!.id != conversation.id) return;
    _mainChannel = _mainChannel!.updateTitle(newTitle);
    _saveConversations();
    notifyListeners();
  }

  /// Set the selected model
  void setSelectedModel(String model) {
    _selectedModel = model;

    // Update main channel's default model
    if (_mainChannel != null) {
      _mainChannel = _mainChannel!.updateModel(model);
    }

    notifyListeners();
  }

  /// Send a message with streaming support.
  /// /new or /reset stay on the shared conversation.
  Future<void> sendMessage(String content) async {
    final trimmed = content.trim();
    if (trimmed.isEmpty || _mainChannel == null) return;

    // Handle /new and /reset commands — same as Telegram DM
    if (trimmed == '/new' || trimmed == '/reset') {
      resetContext();
      return;
    }

    if (_selectedModel == null) {
      // Use gateway default model - don't require model selection
      appLogger
          .debug('[StreamingChat] No model selected, using gateway default');
    }

    // Cancel any ongoing streaming
    _cancelCurrentStream();

    _setLoading(true);
    _setStreaming(false);

    try {
      // Add user message
      final userMessage = Message.user(content: content.trim());
      _addMessageToCurrentConversation(userMessage);

      // Add streaming message placeholder for assistant
      final streamingModel = _selectedModel ?? 'default';
      final streamingMessage = Message.streaming(model: streamingModel);
      _addMessageToCurrentConversation(streamingMessage);
      _currentStreamingMessageId = streamingMessage.id;

      // Get conversation history for context
      final history = _buildMessageHistory();

      // Get streaming service
      final streamingService = _getStreamingService();
      if (streamingService == null) {
        appLogger.warning(
          '[StreamingChat] No streaming service available, falling back to non-streaming chat',
        );
        if (_mainChannel != null && _mainChannel!.messages.isNotEmpty) {
          final lastMessage = _mainChannel!.messages.last;
          if (lastMessage.isStreaming) {
            _removeLastMessage();
          }
        }
        await _fallbackToNonStreamingChat(content.trim());
        return;
      }

      // Start streaming
      _setStreaming(true);
      _streamingContentSubject.add('');
      _streamingReasoningSubject.add('');
      _activeToolCalls.clear();
      _completedToolCalls.clear();
      _isAgentRunning = false;

      // If the streaming service is Hermes, also listen to agent events
      _subscribeToAgentEvents(streamingService);

      final conversationId = _mainChannel!.id;
      final messageStream = streamingService.streamResponse(
        prompt: content.trim(),
        model: streamingModel,
        conversationId: conversationId,
        history: history,
      );

      // Listen to streaming messages
      _currentStreamSubscription = messageStream.listen(
        _handleStreamingMessage,
        onError: _handleStreamingError,
        onDone: _handleStreamingComplete,
      );
    } catch (e) {
      appLogger.error('[StreamingChat] Error in sendMessage', error: e);

      // Remove streaming message if it was added
      if (_mainChannel != null && _mainChannel!.messages.isNotEmpty) {
        final lastMessage = _mainChannel!.messages.last;
        if (lastMessage.isStreaming) {
          _removeLastMessage();
          appLogger.debug(
            '[StreamingChat] Removed streaming message due to error',
          );
        }
      }

      final errorModel = _selectedModel ?? 'default';
      final errorMessage = Message.assistant(
        content:
            userFacingChatError(e, isConnected: _connectionManager.isConnected),
        model: errorModel,
        status: MessageStatus.error,
        error: e.toString(),
      );
      _addMessageToCurrentConversation(errorMessage);
    } finally {
      _setLoading(false);
      _setStreaming(false);
    }
  }

  /// Handle incoming streaming message chunks
  void _handleStreamingMessage(StreamingMessage streamingMessage) {
    if (streamingMessage.hasError) {
      _handleStreamingError(streamingMessage.error!);
      return;
    }

    if (streamingMessage.isComplete) {
      _handleStreamingComplete();
      return;
    }

    if (streamingMessage.isDataChunk) {
      // Transcript polls send a snapshot for this message id. True deltas are
      // appended only when the new text is not already the full reply.
      // Reasoning is never accumulated — chain-of-thought stays off the chat.
      if (streamingMessage.chunk.isNotEmpty) {
        final next = nextStreamingContent(
          previous: _streamingContentSubject.value,
          incoming: streamingMessage.chunk,
          replaces: streamingMessage.replacesContent,
        );
        _streamingContentSubject.add(next);
      }

      _updateStreamingMessage(_streamingContentSubject.value, null);
    }
  }

  /// Handle streaming error
  void _handleStreamingError(dynamic error) {
    appLogger.error('[StreamingChat] Streaming error: $error');

    _setStreaming(false);
    // Remove only the Thinking placeholder — never blindly drop the last row,
    // which may be the user's just-sent message.
    _removeStreamingPlaceholder();
    _currentStreamingMessageId = '';

    final errorModel = _selectedModel ?? 'default';
    final errorMessage = Message.assistant(
      content: userFacingChatError(error,
          isConnected: _connectionManager.isConnected),
      model: errorModel,
      status: MessageStatus.error,
      error: error.toString(),
    );
    _addMessageToCurrentConversation(errorMessage);
  }

  /// Handle streaming completion
  void _handleStreamingComplete() {
    // Guard against re-entrant calls (isComplete + onDone double-fire)
    if (_currentStreamingMessageId.isEmpty) {
      appLogger
          .debug('[StreamingChat] Skipping duplicate _handleStreamingComplete');
      return;
    }

    appLogger.debug('[StreamingChat] Streaming completed');

    _setStreaming(false);
    _isAgentRunning = false;

    // Convert streaming message to final assistant message.
    // Do not fall back to reasoning text — that would persist chain-of-thought
    // as the visible reply.
    var finalContent = _streamingContentSubject.value;

    // Fallback: if no deltas were emitted but run.completed had output
    if (finalContent.isEmpty && _runCompletedOutput.isNotEmpty) {
      finalContent = _runCompletedOutput;
    }

    // Always remove the streaming placeholder if it exists
    _removeStreamingPlaceholder();

    if (finalContent.isNotEmpty) {
      final completeModel = _selectedModel ?? 'default';

      // Build metadata with tool call history
      final toolCallsMeta = _serializeToolCalls(includeLive: false);

      final assistantMessage = Message.assistant(
        content: finalContent,
        model: completeModel,
        metadata:
            toolCallsMeta.isNotEmpty ? {'tool_calls': toolCallsMeta} : null,
      );
      _addMessageToCurrentConversation(assistantMessage);

      // Auto-rename conversation if it's the first message
      _autoRenameConversation();
    } else {
      appLogger
          .warning('[StreamingChat] Streaming completed with empty content');
    }

    // Clear streaming content and agent state
    _streamingContentSubject.add('');
    _streamingReasoningSubject.add('');
    _currentStreamingMessageId = '';
    _runCompletedOutput = '';
    // Reconcile local reply rows with the harness copy now the turn is done.
    unawaited(_syncSharedChannel());
    _activeToolCalls.clear();
    _completedToolCalls.clear();
  }

  /// Subscribe to agent events if the streaming service supports them.
  void _subscribeToAgentEvents(StreamingService streamingService) {
    _agentEventSubscription?.cancel();
    _agentEventSubscription = null;

    Stream<AgentEvent>? eventStream;
    if (streamingService is HermesStreamingService) {
      eventStream = streamingService.agentEventStream;
    }

    if (eventStream != null) {
      _agentEventSubscription = eventStream.listen(
        _handleAgentEvent,
        onError: (e) {
          appLogger.warning('[StreamingChat] Agent event stream error: $e');
        },
      );
    }
  }

  /// Serialize tool calls to a list of maps for storage/UI.
  List<Map<String, dynamic>> _serializeToolCalls({bool includeLive = true}) {
    return allToolCalls.map((tc) {
      final map = <String, dynamic>{
        'name': tc.name,
        'preview': tc.preview,
        'isCompleted': tc.isCompleted,
        'isError': tc.isError,
        'duration': tc.durationSeconds,
      };
      if (includeLive) map['emoji'] = tc.emoji;
      return map;
    }).toList();
  }

  /// Handle a structured agent event.
  void _handleAgentEvent(AgentEvent event) {
    switch (event) {
      case AgentToolStarted(:final tool, :final preview):
        _isAgentRunning = true;
        final toolCall = ToolCall(
          name: tool,
          preview: preview,
          startedAt: DateTime.now(),
        );
        _activeToolCalls.add(toolCall);
        appLogger
            .info('[StreamingChat] Tool started: $tool (${preview ?? "..."})');
        notifyListeners();

      case AgentToolCompleted(:final tool, :final duration, :final isError):
        // Find the matching active tool call and complete it
        final index = _activeToolCalls.indexWhere((tc) => tc.name == tool);
        if (index != -1) {
          final active = _activeToolCalls.removeAt(index);
          final completed = active.copyWith(
            isCompleted: true,
            isError: isError,
            durationSeconds: duration,
          );
          _completedToolCalls.add(completed);
        }
        // If no active tools remain, the agent is back to thinking/responding
        if (_activeToolCalls.isEmpty) {
          _isAgentRunning = false;
        }
        appLogger.info(
          '[StreamingChat] Tool completed: $tool (${duration}s, error: $isError)',
        );
        notifyListeners();

      case AgentRunCompleted(:final output, :final usage):
        _isAgentRunning = false;
        // Store output as fallback in case no message.delta events
        // were emitted (some models only produce a final output).
        if (output.isNotEmpty) {
          _runCompletedOutput = output;
        }
        if (usage != null) {
          appLogger.info(
            '[StreamingChat] Run completed: ${usage['total_tokens']} tokens',
          );
        }

      case AgentRunFailed(:final error):
        _isAgentRunning = false;
        appLogger.error('[StreamingChat] Run failed: $error');

      case AgentReasoningAvailable():
        // Reasoning is already handled via the StreamingMessage text pipeline.
        break;

      case AgentMessageDelta():
        // Text deltas are already handled via the StreamingMessage text pipeline.
        break;

      case AgentUnknown(:final eventType):
        appLogger.debug('[StreamingChat] Unknown agent event: $eventType');
    }

    // Update the streaming message metadata with tool calls for live UI
    _updateStreamingMessageWithToolCalls();
  }

  /// Update the streaming message content.
  void _updateStreamingMessage(String content, String? reasoning) {
    _updateMessageInConversation(
      _currentStreamingMessageId,
      (msg) => msg.copyWith(content: content, reasoning: reasoning),
    );
  }

  /// Update the streaming message's metadata with tool calls for live UI.
  void _updateStreamingMessageWithToolCalls() {
    final toolCallsMeta = _serializeToolCalls(includeLive: true);
    if (toolCallsMeta.isEmpty) return;
    _updateMessageInConversation(
      _currentStreamingMessageId,
      (msg) => msg.copyWith(
        metadata: {
          ...?msg.metadata,
          'tool_calls': toolCallsMeta,
          'isAgentRunning': _isAgentRunning,
        },
      ),
    );
  }

  void _addMessageToCurrentConversation(Message message) {
    if (_mainChannel == null) return;
    _mainChannel = _mainChannel!.addMessage(message);
    _saveConversations();
    notifyListeners();
  }

  /// Find a message in the current conversation and update it.
  bool _updateMessageInConversation(
    String messageId,
    Message Function(Message) updater,
  ) {
    if (_mainChannel == null || messageId.isEmpty) return false;
    final msgIndex =
        _mainChannel!.messages.indexWhere((m) => m.id == messageId);
    if (msgIndex == -1) return false;
    final updatedMessage = updater(_mainChannel!.messages[msgIndex]);
    final updatedMessages = List<Message>.from(_mainChannel!.messages);
    updatedMessages[msgIndex] = updatedMessage;
    _mainChannel = _mainChannel!.copyWith(
      messages: updatedMessages,
      updatedAt: DateTime.now(),
    );
    notifyListeners();
    return true;
  }

  /// Auto-rename the conversation if it's the first message
  Future<void> _autoRenameConversation() async {
    final conversation = _mainChannel;
    if (conversation == null || conversation.title != 'New Chat') return;
    // Main channel title is the configured agent name, so this only fires
    // if a conversation was created with the 'New Chat' default title.
    if (conversation.userMessageCount != 1) return;

    final firstUserMessage =
        conversation.messages.firstWhere((m) => m.isUser).content;

    appLogger.debug(
      '[StreamingChat] Auto-renaming conversation based on: "$firstUserMessage"',
    );

    try {
      final prompt =
          'Generate a short, catchy title (max 5-6 words) for a conversation that starts with: "$firstUserMessage". Respond only with the title text, no quotes or prefix.';

      final renameModel = _selectedModel ?? 'default';
      final newTitle = await _connectionManager.sendChatMessage(
        model: renameModel,
        message: prompt,
        history: [], // Send as a fresh request to avoid context confusion
      );

      if (newTitle != null && newTitle.trim().isNotEmpty) {
        var cleanTitle =
            newTitle.trim().replaceAll('"', '').replaceAll("'", '');
        // Remove trailing punctuation if it's just a period
        if (cleanTitle.endsWith('.') && !cleanTitle.endsWith('...')) {
          cleanTitle = cleanTitle.substring(0, cleanTitle.length - 1);
        }

        updateConversationTitle(conversation, cleanTitle);
        appLogger.info(
          '[StreamingChat] Auto-renamed conversation to: $cleanTitle',
        );
      }
    } catch (e) {
      appLogger.error(
        '[StreamingChat] Failed to auto-rename conversation',
        error: e,
      );
    }
  }

  /// Get the appropriate streaming service
  StreamingService? _getStreamingService() {
    // Use connection manager to get the best streaming service
    return _connectionManager.getStreamingService();
  }

  /// Fallback to non-streaming chat when streaming is not available
  Future<void> _fallbackToNonStreamingChat(String content) async {
    try {
      appLogger.debug('[StreamingChat] Using fallback non-streaming chat');

      // Add loading message for assistant
      final fallbackModel = _selectedModel ?? 'default';
      final loadingMessage = Message.loading(model: fallbackModel);
      _addMessageToCurrentConversation(loadingMessage);

      // Get conversation history for context
      final history = _buildMessageHistory();

      // Use connection manager for fallback chat
      final response = await _connectionManager.sendChatMessage(
        model: fallbackModel,
        message: content,
        history: history,
      );

      // Remove loading message
      _removeLastMessage();

      if (response != null) {
        final assistantMessage = Message.assistant(
          content: response,
          model: fallbackModel,
        );
        _addMessageToCurrentConversation(assistantMessage);
        appLogger.debug('[StreamingChat] Fallback chat completed successfully');

        // Auto-rename conversation if it's the first message
        await _autoRenameConversation();
      } else {
        final offlineMessage = Message.assistant(
          content:
              'Agent runtime not configured \u2014 your message has been saved locally. Configure an agent in Settings to get AI responses and use desktop control features. The app works fully offline in the meantime.',
          model: fallbackModel,
        );
        _addMessageToCurrentConversation(offlineMessage);
      }
    } catch (e) {
      appLogger.error('[StreamingChat] Fallback chat error', error: e);

      // Remove loading message if it exists
      if (_mainChannel != null && _mainChannel!.messages.isNotEmpty) {
        final lastMessage = _mainChannel!.messages.last;
        if (lastMessage.isLoading) {
          _removeLastMessage();
        }
      }

      final fallbackModel = _selectedModel ?? 'default';
      final errorMessage = Message.assistant(
        content:
            userFacingChatError(e, isConnected: _connectionManager.isConnected),
        model: fallbackModel,
        status: MessageStatus.error,
        error: e.toString(),
      );
      _addMessageToCurrentConversation(errorMessage);
    }
  }

  /// Cancel current streaming
  void _cancelCurrentStream() {
    _currentStreamSubscription?.cancel();
    _currentStreamSubscription = null;
    _agentEventSubscription?.cancel();
    _agentEventSubscription = null;
    _setStreaming(false);
    _isAgentRunning = false;
    _activeToolCalls.clear();
    _completedToolCalls.clear();
    _streamingContentSubject.add('');
    _streamingReasoningSubject.add('');
  }

  /// Remove the last message from current conversation
  void _removeStreamingPlaceholder() {
    final id = _currentStreamingMessageId;
    if (id.isEmpty || _mainChannel == null) return;
    if (!_mainChannel!.messages.any((m) => m.id == id)) return;
    _mainChannel = _mainChannel!.removeMessage(id);
    _saveConversations();
    notifyListeners();
  }

  void _removeLastMessage() {
    try {
      if (_mainChannel == null || _mainChannel!.messages.isEmpty) return;
      final updated = _mainChannel!.copyWith(
        messages: _mainChannel!.messages
            .sublist(0, _mainChannel!.messages.length - 1),
        updatedAt: DateTime.now(),
      );
      _mainChannel = updated;
      _saveConversations();
      notifyListeners();
    } catch (e) {
      appLogger.error('Error removing last message', error: e);
    }
  }

  /// Build message history for API
  List<Map<String, String>> _buildMessageHistory() {
    if (_mainChannel == null) return [];
    return _mainChannel!.messages
        .where(
          (m) =>
              m.role != MessageRole.system &&
              m.status == MessageStatus.sent &&
              !m.isStreaming,
        )
        .map(
          (m) => {
            'role': m.role == MessageRole.user ? 'user' : 'assistant',
            'content': m.content,
          },
        )
        .toList();
  }

  /// Set loading state
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  /// Set streaming state
  void _setStreaming(bool streaming) {
    _isStreaming = streaming;
    notifyListeners();
  }

  /// Clear all conversations (same as reset)
  void clearAllConversations() {
    _cancelCurrentStream();
    resetContext();
    _storageService.clearAllConversations().catchError((e) {
      appLogger.error(
        '[StreamingChat] Error clearing conversations from storage',
        error: e,
      );
    });
    notifyListeners();
  }

  @override
  void dispose() {
    appLogger.debug('[StreamingChat] Disposing service');

    _sharedChannelTimer?.cancel();
    _cancelCurrentStream();
    _streamingContentSubject.close();
    _streamingReasoningSubject.close();
    _connectionManager.removeListener(_onConnectionManagerChanged);
    _avatarState?.removeListener(_onAgentNameChanged);
    _storageService.dispose();

    super.dispose();
  }

  void _bindAgentNameListener() {
    try {
      if (!di.serviceLocator.isRegistered<AvatarStateService>()) return;
      _avatarState = di.serviceLocator<AvatarStateService>();
      _avatarState!.addListener(_onAgentNameChanged);
    } catch (_) {}
  }

  void _onAgentNameChanged() {
    _applyAgentNameToMainChannel();
  }

  void _applyAgentNameToMainChannel({bool persist = true}) {
    if (_mainChannel == null) return;
    final name = connectedAgentDisplayName();
    if (_mainChannel!.title == name) return;
    _mainChannel = _mainChannel!.updateTitle(name);
    if (persist) _saveConversations();
    notifyListeners();
  }
}
