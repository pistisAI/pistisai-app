import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:pistisai/models/agent_event.dart';
import 'package:pistisai/models/streaming_message.dart';
import 'package:pistisai/services/hermes/hermes_streaming_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('HermesStreamingService', () {
    group('constructor and initial state', () {
      test('constructs with default base URL', () {
        final service = HermesStreamingService();
        expect(service.baseUrl, 'http://127.0.0.1:8642');
        service.dispose();
      });

      test('constructs with custom base URL and apiKey', () {
        final service = HermesStreamingService(
          baseUrl: 'http://localhost:9999',
          apiKey: 'sk-test',
        );
        expect(service.baseUrl, 'http://localhost:9999');
        service.dispose();
      });

      test('initial connection state is disconnected', () {
        final service = HermesStreamingService();
        expect(service.connection.isActive, isFalse);
        expect(
            service.connection.state, StreamingConnectionState.disconnected);
        service.dispose();
      });

      test('message stream is broadcast', () {
        final service = HermesStreamingService();
        expect(service.messageStream.isBroadcast, isTrue);
        service.dispose();
      });

      test('agent event stream is broadcast', () {
        final service = HermesStreamingService();
        expect(service.agentEventStream.isBroadcast, isTrue);
        service.dispose();
      });
    });

    group('establishConnection', () {
      test('sets error state when server is unreachable', () async {
        final service = HermesStreamingService();
        await service.establishConnection();
        expect(service.connection.hasError, isTrue);
        expect(service.connection.state, StreamingConnectionState.error);
        service.dispose();
      });

      test('closeConnection resets to disconnected', () async {
        final service = HermesStreamingService();
        await service.closeConnection();
        expect(service.connection.isActive, isFalse);
        expect(
            service.connection.state, StreamingConnectionState.disconnected);
        service.dispose();
      });
    });

    group('testConnection', () {
      test('returns false when server is unreachable', () async {
        final service = HermesStreamingService();
        final result = await service.testConnection();
        expect(result, isFalse);
        service.dispose();
      });
    });

    group('getAvailableModels', () {
      test('returns empty list when not connected', () async {
        final service = HermesStreamingService();
        final models = await service.getAvailableModels();
        expect(models, isEmpty);
        service.dispose();
      });
    });

    group('streamResponse', () {
      test('yields error message when not connected', () async {
        final service = HermesStreamingService();
        final messages = await service
            .streamResponse(
              prompt: 'Hello',
              model: 'hermes-agent',
              conversationId: 'conv-1',
            )
            .toList();

        expect(messages, isNotEmpty);
        expect(messages.last.hasError, isTrue);
        expect(messages.last.error, contains('Not connected'));
        service.dispose();
      });
    });

    group('complete (non-streaming)', () {
      test('returns null when not connected', () async {
        final service = HermesStreamingService();
        final result = await service.complete(
          prompt: 'Hello',
          model: 'hermes-agent',
        );
        expect(result, isNull);
        service.dispose();
      });
    });

    group('startRun', () {
      test('returns null when not connected', () async {
        final service = HermesStreamingService();
        final runId = await service.startRun(input: 'Hello');
        expect(runId, isNull);
        service.dispose();
      });
    });

    group('streamRunEvents', () {
      test('yields AgentRunFailed on connection error', () async {
        final service = HermesStreamingService();
        final events = await service.streamRunEvents('run-123').toList();
        expect(events, isNotEmpty);
        expect(events.first, isA<AgentRunFailed>());
        service.dispose();
      });
    });

    group('dispose', () {
      test('closes streams and resets state', () {
        final service = HermesStreamingService();
        service.dispose();
        expect(
            service.connection.state, StreamingConnectionState.disconnected);
      });
    });

    group('AgentEvent model behavior', () {
      test('AgentMessageDelta with empty delta is valid', () {
        final delta = AgentMessageDelta(
          runId: 'run-1',
          timestamp: 1000.0,
          delta: '',
        );
        expect(delta.delta, isEmpty);
        expect(delta.eventTypeLabel, 'message.delta');
      });

      test('AgentMessageDelta with content is valid', () {
        final delta = AgentMessageDelta(
          runId: 'run-1',
          timestamp: 1000.0,
          delta: 'Hello world',
        );
        expect(delta.delta, 'Hello world');
      });

      test('AgentReasoningAvailable with text is valid', () {
        final reasoning = AgentReasoningAvailable(
          runId: 'run-1',
          timestamp: 1000.0,
          text: 'Thinking step by step...',
        );
        expect(reasoning.text, 'Thinking step by step...');
        expect(reasoning.eventTypeLabel, 'reasoning.available');
      });

      test('AgentRunCompleted has output and usage', () {
        final completed = AgentRunCompleted(
          runId: 'run-1',
          timestamp: 1000.0,
          output: 'Final response',
          usage: {'prompt_tokens': 10, 'completion_tokens': 5},
        );
        expect(completed.output, 'Final response');
        expect(completed.usage, isNotNull);
        expect(completed.usage!['prompt_tokens'], 10);
        expect(completed.eventTypeLabel, 'run.completed');
      });

      test('AgentRunFailed has error message', () {
        final failed = AgentRunFailed(
          runId: 'run-1',
          timestamp: 1000.0,
          error: 'Something went wrong',
        );
        expect(failed.error, 'Something went wrong');
        expect(failed.eventTypeLabel, 'run.failed');
      });

      test('AgentToolStarted and AgentToolCompleted are valid', () {
        final started = AgentToolStarted(
          runId: 'run-1',
          timestamp: 1000.0,
          tool: 'terminal',
          preview: 'Running ls',
        );
        expect(started.tool, 'terminal');
        expect(started.preview, 'Running ls');
        expect(started.eventTypeLabel, 'tool.started');

        final completed = AgentToolCompleted(
          runId: 'run-1',
          timestamp: 1001.0,
          tool: 'terminal',
          duration: 0.5,
          isError: false,
        );
        expect(completed.tool, 'terminal');
        expect(completed.duration, 0.5);
        expect(completed.isError, isFalse);
        expect(completed.eventTypeLabel, 'tool.completed');
      });

      test('AgentEvent.fromJson parses all event types', () {
        final delta = AgentEvent.fromJson({
          'event': 'message.delta',
          'run_id': 'run-1',
          'timestamp': 1000.0,
          'delta': 'Hello',
        });
        expect(delta, isA<AgentMessageDelta>());
        expect((delta as AgentMessageDelta).delta, 'Hello');

        final reasoning = AgentEvent.fromJson({
          'event': 'reasoning.available',
          'run_id': 'run-1',
          'timestamp': 1001.0,
          'text': 'Thinking...',
        });
        expect(reasoning, isA<AgentReasoningAvailable>());
        expect((reasoning as AgentReasoningAvailable).text, 'Thinking...');

        final completed = AgentEvent.fromJson({
          'event': 'run.completed',
          'run_id': 'run-1',
          'timestamp': 1002.0,
          'output': 'Done',
        });
        expect(completed, isA<AgentRunCompleted>());
        expect((completed as AgentRunCompleted).output, 'Done');

        final failed = AgentEvent.fromJson({
          'event': 'run.failed',
          'run_id': 'run-1',
          'timestamp': 1003.0,
          'error': 'Error!',
        });
        expect(failed, isA<AgentRunFailed>());
        expect((failed as AgentRunFailed).error, 'Error!');

        final toolStarted = AgentEvent.fromJson({
          'event': 'tool.started',
          'run_id': 'run-1',
          'timestamp': 1004.0,
          'tool': 'web_search',
          'preview': 'Searching...',
        });
        expect(toolStarted, isA<AgentToolStarted>());
        expect((toolStarted as AgentToolStarted).tool, 'web_search');

        final toolCompleted = AgentEvent.fromJson({
          'event': 'tool.completed',
          'run_id': 'run-1',
          'timestamp': 1005.0,
          'tool': 'web_search',
          'duration': 1.2,
          'error': false,
        });
        expect(toolCompleted, isA<AgentToolCompleted>());
        expect((toolCompleted as AgentToolCompleted).duration, 1.2);

        final unknown = AgentEvent.fromJson({
          'event': 'custom.event',
          'run_id': 'run-1',
          'timestamp': 1006.0,
        });
        expect(unknown, isA<AgentUnknown>());
        expect((unknown as AgentUnknown).eventType, 'custom.event');
      });
    });

    group('StreamingMessage model behavior', () {
      test('StreamingMessage.chunk creates data chunk', () {
        final msg = StreamingMessage.chunk(
          id: 'msg-1',
          conversationId: 'conv-1',
          chunk: 'Hello',
          sequence: 0,
          model: 'hermes-agent',
        );
        expect(msg.chunk, 'Hello');
        expect(msg.isComplete, isFalse);
        expect(msg.hasError, isFalse);
        expect(msg.isDataChunk, isTrue);
      });

      test('StreamingMessage.complete creates completion signal', () {
        final msg = StreamingMessage.complete(
          id: 'msg-1',
          conversationId: 'conv-1',
          sequence: 5,
          model: 'hermes-agent',
        );
        expect(msg.isComplete, isTrue);
        expect(msg.chunk, isEmpty);
        expect(msg.isDataChunk, isFalse);
      });

      test('StreamingMessage.error creates error message', () {
        final msg = StreamingMessage.error(
          id: 'msg-1',
          conversationId: 'conv-1',
          error: 'Something failed',
          sequence: 0,
        );
        expect(msg.hasError, isTrue);
        expect(msg.error, 'Something failed');
        expect(msg.isComplete, isTrue);
      });

      test('StreamingMessage with reasoning is data chunk', () {
        final msg = StreamingMessage.chunk(
          id: 'msg-1',
          conversationId: 'conv-1',
          chunk: '',
          reasoning: 'Thinking...',
          sequence: 0,
        );
        expect(msg.reasoning, 'Thinking...');
        expect(msg.isDataChunk, isTrue);
      });

      test('StreamingMessage equality uses id, conversationId, sequence', () {
        final msg1 = StreamingMessage.chunk(
          id: 'msg-1',
          conversationId: 'conv-1',
          chunk: 'Hello',
          sequence: 0,
        );
        final msg2 = StreamingMessage.chunk(
          id: 'msg-1',
          conversationId: 'conv-1',
          chunk: 'Hello',
          sequence: 0,
        );
        final msg3 = StreamingMessage.chunk(
          id: 'msg-1',
          conversationId: 'conv-1',
          chunk: 'World',
          sequence: 1,
        );
        expect(msg1, equals(msg2));
        expect(msg1, isNot(equals(msg3)));
      });

      test('StreamingMessage round-trips through JSON', () {
        final original = StreamingMessage.chunk(
          id: 'msg-1',
          conversationId: 'conv-1',
          chunk: 'Hello',
          reasoning: 'Thinking...',
          sequence: 0,
          model: 'hermes-agent',
        );
        final json = original.toJson();
        final restored = StreamingMessage.fromJson(json);
        expect(restored.id, original.id);
        expect(restored.conversationId, original.conversationId);
        expect(restored.chunk, original.chunk);
        expect(restored.reasoning, original.reasoning);
        expect(restored.sequence, original.sequence);
        expect(restored.model, original.model);
      });
    });
  });
}
