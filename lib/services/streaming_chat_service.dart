import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:rxdart/rxdart.dart';
import '../models/agent_event.dart';
import '../models/conversation.dart';
import '../models/message.dart';
import '../models/streaming_message.dart';

import 'streaming_service.dart';
import 'hermes/hermes_streaming_service.dart';
import 'hermes/hermes_process_client.dart';

import 'connection_manager_service.dart';
import 'conversation_storage_service.dart';
import 'auth_service.dart';
import '../utils/logger.dart';

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
  }

  /// The main channel — a single persistent conversation with Zoid.
  Conversation? _mainChannel;

  // Backward-compatible aliases so legacy code continues to work.
  List<Conversation> get _conversations =>
      _mainChannel != null ? [_mainChannel!] : [];
  set _conversations(List<Conversation> v) {
    if (v.isNotEmpty) _mainChannel = v.first;
  }
  Conversation? get _currentConversation => _mainChannel;
  set _currentConversation(Conversation? v) {
    if (v != null) _mainChannel = v;
  }

  String? _selectedModel;
  bool _isLoading = false;
  bool _isStreaming = false;

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
  }

  /// Load the main channel from storage
  Future<void> _loadConversations() async {
    try {
      final loaded = await _storageService.loadConversations();

      if (loaded.isNotEmpty) {
        // Find or create the main channel
        final existing = loaded.firstWhere(
          (c) => c.id == 'main-channel',
          orElse: () => Conversation.mainChannel(model: _selectedModel),
        );
        _mainChannel = existing;
        appLogger.info(
          '[StreamingChat] Loaded main channel with ${existing.messages.length} messages',
        );
      } else {
        _createWelcomeConversation();
      }
    } catch (e) {
      appLogger.error('[StreamingChat] Error loading conversations', error: e);
      _createWelcomeConversation();
    }

    notifyListeners();
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

    _mainChannel = Conversation.mainChannel(model: modelToUse);

    final welcomeMessage = Message.system(
      content:
          'Welcome to Pistisai! I\'m ready to help you with any questions or tasks. What would you like to talk about?',
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
      '[StreamingChat] Saved main channel with ${_mainChannel!.messages.length} messages',
    );
  }

  /// Reset the main channel context
  void resetContext() {
    if (_mainChannel == null) {
      _mainChannel = Conversation.mainChannel(model: _selectedModel);
    } else {
      _mainChannel = Conversation.mainChannel(model: _selectedModel);
    }
    _saveConversations();
    notifyListeners();
  }

  /// Select a conversation
  void selectConversation(Conversation? conversation) {
    _currentConversation = conversation;

    // Cancel any ongoing streaming
    _cancelCurrentStream();

    notifyListeners();
  }

  /// Select a conversation by ID (null to deselect)
  void selectConversationById(String? conversationId) {
    if (conversationId == null) {
      _currentConversation = null;
    } else {
      final index = _conversations.indexWhere((c) => c.id == conversationId);
      if (index != -1) {
        _currentConversation = _conversations[index];
      }
    }
    _cancelCurrentStream();
    notifyListeners();
  }

  /// Delete a conversation
  void deleteConversation(Conversation conversation) {
    _conversations.removeWhere((c) => c.id == conversation.id);

    if (_currentConversation?.id == conversation.id) {
      _currentConversation =
          _conversations.isNotEmpty ? _conversations.first : null;
    }

    _saveConversations();
    notifyListeners();
  }

  /// Update conversation title
  void updateConversationTitle(Conversation conversation, String newTitle) {
    final index = _conversations.indexWhere((c) => c.id == conversation.id);
    if (index != -1) {
      _conversations[index] = _conversations[index].updateTitle(newTitle);
      if (_currentConversation?.id == conversation.id) {
        _currentConversation = _conversations[index];
      }
      _saveConversations();
      notifyListeners();
    }
  }

  /// Set the selected model
  void setSelectedModel(String model) {
    _selectedModel = model;

    // Update current conversation's default model
    if (_currentConversation != null) {
      final index = _conversations.indexWhere(
        (c) => c.id == _currentConversation!.id,
      );
      if (index != -1) {
        _conversations[index] = _conversations[index].updateModel(model);
        _currentConversation = _conversations[index];
      }
    }

    notifyListeners();
  }

  /// Send a message with streaming support.
  /// /new or /reset clears context without sending.
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

      final conversationId = _currentConversation!.id;
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
      if (_currentConversation != null &&
          _currentConversation!.messages.isNotEmpty) {
        final lastMessage = _currentConversation!.messages.last;
        if (lastMessage.isStreaming) {
          _removeLastMessage();
          appLogger.debug(
            '[StreamingChat] Removed streaming message due to error',
          );
        }
      }

      final errorModel = _selectedModel ?? 'default';
      final errorMessage = Message.assistant(
        content: 'Sorry, I encountered an error: ${e.toString()}',
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
      // Update content
      if (streamingMessage.chunk.isNotEmpty) {
        final currentContent = _streamingContentSubject.value;
        final newContent = currentContent + streamingMessage.chunk;
        _streamingContentSubject.add(newContent);
      }

      // Update reasoning
      if (streamingMessage.reasoning != null &&
          streamingMessage.reasoning!.isNotEmpty) {
        final currentReasoning = _streamingReasoningSubject.value;
        final newReasoning = currentReasoning + streamingMessage.reasoning!;
        _streamingReasoningSubject.add(newReasoning);
      }

      // Update the streaming message in the conversation
      _updateStreamingMessage(
        _streamingContentSubject.value,
        _streamingReasoningSubject.value,
      );
    }
  }

  /// Handle streaming error
  void _handleStreamingError(dynamic error) {
    appLogger.error('[StreamingChat] Streaming error: $error');

    _setStreaming(false);
    _removeLastMessage();

    final errorModel = _selectedModel ?? 'default';
    final errorMessage = Message.assistant(
      content:
          'Sorry, I encountered an error while streaming: ${error.toString()}',
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
      appLogger.debug('[StreamingChat] Skipping duplicate _handleStreamingComplete');
      return;
    }

    appLogger.debug('[StreamingChat] Streaming completed');

    _setStreaming(false);
    _isAgentRunning = false;

    // Convert streaming message to final assistant message
    var finalContent = _streamingContentSubject.value;
    final finalReasoning = _streamingReasoningSubject.value;

    // Fallback: if no deltas were emitted but run.completed had output
    if (finalContent.isEmpty && _runCompletedOutput.isNotEmpty) {
      finalContent = _runCompletedOutput;
    }

    // Always remove the streaming placeholder if it exists
    if (_currentConversation != null &&
        _currentConversation!.messages.isNotEmpty &&
        _currentConversation!.messages.last.id == _currentStreamingMessageId) {
      _removeLastMessage();
    }

    if (finalContent.isNotEmpty || finalReasoning.isNotEmpty) {
      final completeModel = _selectedModel ?? 'default';

      // Build metadata with tool call history
      final toolCallsMeta = _serializeToolCalls(includeLive: false);

      final assistantMessage = Message.assistant(
        content: finalContent,
        reasoning: finalReasoning.isNotEmpty ? finalReasoning : null,
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
    } else if (streamingService is HermesProcessClient) {
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
    final msgIndex = _mainChannel!.messages.indexWhere((m) => m.id == messageId);
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
        final errorMessage = Message.assistant(
          content:
              'Sorry, I encountered an error while processing your request.',
          model: fallbackModel,
          status: MessageStatus.error,
          error: 'Connection error',
        );
        _addMessageToCurrentConversation(errorMessage);
      }
    } catch (e) {
      appLogger.error('[StreamingChat] Fallback chat error', error: e);

      // Remove loading message if it exists
      if (_currentConversation != null &&
          _currentConversation!.messages.isNotEmpty) {
        final lastMessage = _currentConversation!.messages.last;
        if (lastMessage.isLoading) {
          _removeLastMessage();
        }
      }

      final fallbackModel = _selectedModel ?? 'default';
      final errorMessage = Message.assistant(
        content: 'Sorry, I encountered an error: ${e.toString()}',
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
  void _removeLastMessage() {
    try {
      if (_mainChannel == null || _mainChannel!.messages.isEmpty) return;
      final updated = _mainChannel!.copyWith(
        messages: _mainChannel!.messages.sublist(0, _mainChannel!.messages.length - 1),
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

    _cancelCurrentStream();
    _streamingContentSubject.close();
    _streamingReasoningSubject.close();
    _connectionManager.removeListener(_onConnectionManagerChanged);
    _storageService.dispose();

    super.dispose();
  }
}
