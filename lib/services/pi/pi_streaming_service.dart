import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../models/agent_event.dart';
import '../../models/streaming_message.dart';
import '../streaming_service.dart';
import '../../utils/logger.dart';

/// Streaming service for Pi coding agent (RPC mode).
///
/// Spawns `pi --mode rpc` as a subprocess and communicates via
/// line-delimited JSON over stdin/stdout (Pi's RPC protocol).
///
/// Unlike Hermes/OpenClaw which connect via HTTP/WebSocket,
/// Pi runs as a local subprocess — no network port needed.
///
/// Pi RPC protocol:
/// - Send: `{"id":"req-1","type":"prompt","message":"hello"}` on stdin
/// - Receive: JSON lines on stdout (events + responses)
///   - `{"type":"message_update","assistantMessageEvent":{"delta":"Hi"}}`
///   - `{"type":"agent_end"}`
///   - `{"type":"tool_execution_start","toolName":"read_file",...}`
class PiStreamingService extends StreamingService {

  final String _model;
  final String _provider;
  final String? _sessionDir;

  Process? _process;
  StreamSubscription? _stdoutSub;
  StreamSubscription? _stderrSub;
  int _requestId = 0;
  int _sequence = 0;
  String? _currentConversationId;
  final Map<String, Completer<Map<String, dynamic>>> _pending = {};

  final StreamController<StreamingMessage> _messageController =
      StreamController<StreamingMessage>.broadcast();
  final StreamController<AgentEvent> _agentEventController =
      StreamController<AgentEvent>.broadcast();
  StreamingConnection _connection = StreamingConnection.disconnected();

  /// Stream of structured agent events (tool calls, lifecycle).
  Stream<AgentEvent> get agentEventStream => _agentEventController.stream;

  /// The currently loaded model name.
  String get currentModel => _model;

  PiStreamingService({
    String model = 'google_gemma-4-E4B-it',
    String provider = 'llamacpp',
    String? sessionDir,
  })  : _model = model,
        _provider = provider,
        _sessionDir = sessionDir;

  // ---------------------------------------------------------------------------
  // StreamingService interface
  // ---------------------------------------------------------------------------

  @override
  Stream<StreamingMessage> get messageStream => _messageController.stream;

  @override
  StreamingConnection get connection => _connection;

  @override
  Future<void> establishConnection() async {
    _connection = StreamingConnection.connecting('pi://$_model');
    notifyListeners();

    try {
      final args = ['--mode', 'rpc', '--provider', _provider, '--model', _model];
      if (_sessionDir != null) {
        args.addAll(['--session-dir', _sessionDir]);
      }

      appLogger.info('Starting Pi subprocess: pi ${args.join(" ")}');
      _process = await Process.start('pi', args);

      // Read stdout line by line (JSONL protocol)
      _stdoutSub = _process!.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen(_handleLine, onError: (e) {
        appLogger.error('Pi stdout error: $e');
      });

      // Forward stderr to logs
      _stderrSub = _process!.stderr
          .transform(utf8.decoder)
          .listen((line) => appLogger.debug('[Pi stderr] $line'));

      // Monitor process exit
      _process!.exitCode.then((code) {
        appLogger.warning('Pi subprocess exited with code $code');
        _connection = StreamingConnection.disconnected();
        notifyListeners();
      });

      _connection = StreamingConnection.connected('pi://$_model');
      notifyListeners();
      appLogger.info('Pi subprocess started (model: $_model, provider: $_provider)');
    } catch (e) {
      appLogger.error('Failed to start Pi subprocess: $e');
      _connection = StreamingConnection.disconnected();
      notifyListeners();
      rethrow;
    }
  }

  @override
  Future<void> closeConnection() async {
    await _stdoutSub?.cancel();
    await _stderrSub?.cancel();
    _process?.kill();
    _process = null;
    _connection = StreamingConnection.disconnected();
    notifyListeners();
    appLogger.info('Pi subprocess stopped');
  }

  @override
  Stream<StreamingMessage> streamResponse({
    required String prompt,
    required String model,
    required String conversationId,
    List<Map<String, String>>? history,
  }) async* {
    if (_process == null) {
      await establishConnection();
    }

    _currentConversationId = conversationId;
    _sequence = 0;
    final requestId = 'req-${_requestId++}';
    final completer = Completer<Map<String, dynamic>>();
    _pending[requestId] = completer;

    // Send prompt to Pi
    final payload = jsonEncode({
      'id': requestId,
      'type': 'prompt',
      'message': prompt,
      if (model != 'default') 'model': model,
    });
    _process!.stdin.writeln(payload);

    appLogger.debug('Sent prompt to Pi (id: $requestId)');

    // Listen for events until we get a complete message
    await for (final event in _messageController.stream) {
      yield event;
      if (event.isComplete) break;
    }
  }

  @override
  Future<bool> testConnection() async {
    try {
      if (_process == null) {
        // Check if `pi` binary exists and runs
        final result = await Process.run('pi', ['--version']);
        return result.exitCode == 0;
      }
      return _process != null;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<List<String>> getAvailableModels() async {
    // Pi uses whatever model is configured in llama.cpp
    // Return the current model as the only available one
    return [_model];
  }

  @override
  void dispose() {
    closeConnection();
    _messageController.close();
    _agentEventController.close();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Internal: Pi RPC protocol handling
  // ---------------------------------------------------------------------------

  void _handleLine(String line) {
    if (line.trim().isEmpty) return;

    Map<String, dynamic> json;
    try {
      json = jsonDecode(line) as Map<String, dynamic>;
    } catch (e) {
      appLogger.warning('Failed to parse Pi JSON: $e — line: $line');
      return;
    }

    final type = json['type'] as String?;
    final convId = _currentConversationId ?? 'pi';
    final ts = DateTime.now().millisecondsSinceEpoch.toDouble() / 1000.0;
    appLogger.debug('Pi event: $type');

    // Handle responses to our commands (have an id)
    if (json.containsKey('id') && json['id'] is String) {
      final completer = _pending.remove(json['id']);
      completer?.complete(json);
    }

    // Handle streaming events
    switch (type) {
      case 'message_update':
        final delta = json['assistantMessageEvent']?['delta'] as String?;
        if (delta != null && delta.isNotEmpty) {
          _messageController.add(StreamingMessage.chunk(
            id: 'pi-msg-${_requestId}',
            conversationId: convId,
            chunk: delta,
            sequence: _sequence++,
            model: _model,
          ));
        }
        break;

      case 'agent_end':
        _messageController.add(StreamingMessage.complete(
          id: 'pi-end-${_requestId}',
          conversationId: convId,
          sequence: _sequence++,
          model: _model,
        ));
        break;

      case 'agent_error':
        final error = json['error'] as String? ?? 'Unknown Pi error';
        _messageController.add(StreamingMessage.error(
          id: 'pi-err-${_requestId}',
          conversationId: convId,
          error: error,
          sequence: _sequence++,
        ));
        break;

      case 'tool_execution_start':
        final toolName = json['toolName'] as String? ?? 'unknown';
        _agentEventController.add(AgentToolStarted(
          runId: convId,
          timestamp: ts,
          tool: toolName,
        ));
        break;

      case 'tool_execution_result':
        final toolName = json['toolName'] as String? ?? 'unknown';
        final isError = json['isError'] as bool? ?? false;
        _agentEventController.add(AgentToolCompleted(
          runId: convId,
          timestamp: ts,
          tool: toolName,
          duration: 0,
          isError: isError,
        ));
        break;

      case 'reasoning_update':
        final reasoning = json['reasoning'] as String?;
        if (reasoning != null && reasoning.isNotEmpty) {
          _messageController.add(StreamingMessage.chunk(
            id: 'pi-reason-${_requestId}',
            conversationId: convId,
            chunk: '',
            reasoning: reasoning,
            sequence: _sequence++,
            model: _model,
          ));
        }
        break;

      default:
        appLogger.debug('Unhandled Pi event type: $type');
    }
  }
}
