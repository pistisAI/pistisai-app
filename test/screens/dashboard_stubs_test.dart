import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pistisai/models/agent_event.dart';
import 'package:pistisai/screens/dashboard/event_stream_screen.dart';
import 'package:pistisai/screens/dashboard/widgets/agent_list_item.dart';
import 'package:pistisai/services/agent_lifecycle_service.dart';
import 'package:pistisai/services/agent_runtime/agent_runtime_client.dart';
import 'package:pistisai/services/connection_manager_service.dart';

/// Fake runtime client exposing a controllable [agentEventStream].
class _FakeRuntimeClient implements AgentRuntimeClient {
  final StreamController<AgentEvent> controller =
      StreamController<AgentEvent>.broadcast();

  @override
  Stream<AgentEvent> get agentEventStream => controller.stream;

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

/// Minimal [ConnectionManagerService] stub that only supplies the
/// active runtime client the event stream screen reads.
class _StubConnectionManager implements ConnectionManagerService {
  final AgentRuntimeClient? client;
  _StubConnectionManager(this.client);

  @override
  AgentRuntimeClient? get activeRuntimeClient => client;

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  group('EventStreamScreen', () {
    testWidgets('shows not-connected state when no runtime client',
        (tester) async {
      await tester.pumpWidget(_wrap(
          EventStreamScreen(
              connectionManager: _StubConnectionManager(null))));

      expect(find.text('No agent runtime connected'), findsOneWidget);
      expect(find.byType(ListView), findsNothing);
    });

    testWidgets('renders incoming events and supports clear', (tester) async {
      final fake = _FakeRuntimeClient();
      await tester.pumpWidget(_wrap(EventStreamScreen(
          connectionManager: _StubConnectionManager(fake))));
      await tester.pump();

      fake.controller.add(AgentToolStarted(
        runId: 'r1',
        timestamp: 1000.0,
        tool: 'terminal',
        preview: 'ls -la',
      ));
      await tester.pumpAndSettle();

      expect(find.text('tool.started'), findsOneWidget);
      expect(find.text('terminal: ls -la'), findsOneWidget);

      await tester.tap(find.byTooltip('Clear'));
      await tester.pumpAndSettle();

      expect(find.text('Waiting for agent events…'), findsOneWidget);
    });

    testWidgets('pause stops new events from rendering', (tester) async {
      final fake = _FakeRuntimeClient();
      await tester.pumpWidget(_wrap(EventStreamScreen(
          connectionManager: _StubConnectionManager(fake))));
      await tester.pump();

      fake.controller.add(AgentToolStarted(
        runId: 'r1',
        timestamp: 1000.0,
        tool: 'terminal',
      ));
      await tester.pumpAndSettle();
      expect(find.text('tool.started'), findsOneWidget);

      await tester.tap(find.byTooltip('Pause'));
      await tester.pumpAndSettle();

      fake.controller.add(AgentToolCompleted(
        runId: 'r1',
        timestamp: 1001.0,
        tool: 'terminal',
        duration: 1.2,
      ));
      await tester.pumpAndSettle();

      expect(find.text('tool.completed'), findsNothing);
    });
  });

  group('AgentListItem', () {
    AgentInfo makeAgent(AgentLifecycleState state) => AgentInfo(
          id: 'a1',
          name: 'Zoidbot',
          type: 'hermes',
          state: state,
        );

    testWidgets('renders running agent with name and status label',
        (tester) async {
      var tapped = false;
      await tester.pumpWidget(_wrap(AgentListItem(
        agent: makeAgent(AgentLifecycleState.running),
        onTap: () => tapped = true,
      )));

      expect(find.text('Zoidbot'), findsOneWidget);
      expect(find.text('Running'), findsOneWidget);

      await tester.tap(find.byType(ListTile));
      expect(tapped, isTrue);
    });

    testWidgets('renders error state distinctly', (tester) async {
      await tester.pumpWidget(_wrap(AgentListItem(
        agent: makeAgent(AgentLifecycleState.error),
      )));

      expect(find.text('Error'), findsOneWidget);
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
    });
  });
}
