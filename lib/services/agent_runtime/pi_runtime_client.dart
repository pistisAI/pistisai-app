import 'dart:async';

import 'package:pistisai/models/agent_event.dart';
import 'package:pistisai/models/streaming_message.dart';
import 'package:pistisai/services/agent_runtime/agent_runtime_client.dart';
import 'package:pistisai/services/pi/pi_streaming_service.dart';
import 'package:pistisai/services/streaming_service.dart';

/// Pi runtime client — implements AgentRuntimeClient for the Pi coding agent.
///
/// Pi runs as a subprocess in RPC mode (JSONL over stdin/stdout),
/// unlike Hermes/OpenClaw which use HTTP/WebSocket.
class PiRuntimeClient implements AgentRuntimeClient {
  final String model;
  final String provider;
  final String? sessionDir;

  late final PiStreamingService _streamingService;
  RuntimeConnectionState _connectionState = RuntimeConnectionState.disconnected;
  RuntimeCapabilityManifest _capabilityManifest =
      const RuntimeCapabilityManifest(
    chatStreaming: true,
    agentEvents: true,
    toolRequests: true,
    desktopActionRequests: true,
    voice: false, // Pi doesn't have voice (yet)
  );

  PiRuntimeClient({
    this.model = 'google_gemma-4-E4B-it',
    this.provider = 'llamacpp',
    this.sessionDir,
  }) {
    _streamingService = PiStreamingService(
      model: model,
      provider: provider,
      sessionDir: sessionDir,
    );
  }

  @override
  RuntimeIdentity get identity => RuntimeIdentity(
        kind: AgentRuntimeKind.pi,
        id: 'pi://$model',
        name: 'Pi Agent',
        baseUrl: 'pi://local',
      );

  @override
  RuntimeCapabilityManifest get capabilityManifest => _capabilityManifest;

  @override
  RuntimeConnectionState get connectionState => _connectionState;

  @override
  Stream<AgentEvent> get agentEventStream =>
      _streamingService.agentEventStream;

  @override
  StreamingService get streamingService => _streamingService;

  @override
  Future<void> connect() async {
    _connectionState = RuntimeConnectionState.connecting;
    await _streamingService.establishConnection();
    _connectionState = RuntimeConnectionState.connected;
    final models = await _streamingService.getAvailableModels();
    _capabilityManifest = RuntimeCapabilityManifest(
      chatStreaming: true,
      agentEvents: true,
      toolRequests: true,
      desktopActionRequests: true,
      voice: false,
      models: models,
    );
  }

  @override
  Future<void> disconnect() async {
    await _streamingService.closeConnection();
    _connectionState = RuntimeConnectionState.disconnected;
  }

  @override
  Future<RuntimeHealth> health() async {
    final healthy = await _streamingService.testConnection();
    _connectionState = healthy
        ? RuntimeConnectionState.connected
        : RuntimeConnectionState.unhealthy;
    return RuntimeHealth(
      state: _connectionState,
      message: healthy ? 'Pi Agent is reachable' : 'Pi Agent is unreachable',
    );
  }

  @override
  Future<List<String>> getAvailableModels() async {
    final models = await _streamingService.getAvailableModels();
    _capabilityManifest = RuntimeCapabilityManifest(
      chatStreaming: true,
      agentEvents: true,
      toolRequests: true,
      desktopActionRequests: true,
      voice: false,
      models: models,
    );
    return models;
  }

  @override
  Stream<StreamingMessage> streamChat({
    required String prompt,
    required String model,
    required String conversationId,
    List<Map<String, String>>? history,
  }) {
    return _streamingService.streamResponse(
      prompt: prompt,
      model: model,
      conversationId: conversationId,
      history: history,
    );
  }

  @override
  Future<String?> sendChatMessage({
    required String prompt,
    required String model,
    List<Map<String, String>>? history,
  }) async {
    final chunks = StringBuffer();
    final conversationId = DateTime.now().microsecondsSinceEpoch.toString();

    await for (final message in streamChat(
      prompt: prompt,
      model: model,
      conversationId: conversationId,
      history: history,
    )) {
      if (message.hasError) {
        throw StateError(message.error ?? 'Pi stream failed');
      }
      if (message.isDataChunk) {
        chunks.write(message.chunk);
      }
    }

    final response = chunks.toString().trim();
    return response.isEmpty ? null : response;
  }
}
