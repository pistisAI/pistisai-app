import 'dart:async';

import 'package:flutter/material.dart';
import 'package:pistisai/di/locator.dart' as di;
import 'package:pistisai/models/agent_event.dart';
import 'package:pistisai/services/connection_manager_service.dart';

/// Live event stream from the active agent runtime (Hermes).
///
/// Subscribes to [AgentRuntimeClient.agentEventStream] via the
/// [ConnectionManagerService] and renders each event as a timeline entry.
class EventStreamScreen extends StatefulWidget {
  final ConnectionManagerService? connectionManager;

  const EventStreamScreen({super.key, this.connectionManager});

  @override
  State<EventStreamScreen> createState() => _EventStreamScreenState();
}

class _EventStreamScreenState extends State<EventStreamScreen> {
  static const int _maxEvents = 200;

  ConnectionManagerService? _connectionManager;
  StreamSubscription<AgentEvent>? _subscription;
  final List<AgentEvent> _events = [];
  bool _paused = false;
  Stream<AgentEvent>? _eventStream;

  @override
  void initState() {
    super.initState();
    _connect();
  }

  void _connect() {
    if (widget.connectionManager != null) {
      _connectionManager = widget.connectionManager;
    } else {
      try {
        _connectionManager =
            di.serviceLocator.get<ConnectionManagerService>();
      } catch (e) {
        debugPrint('[EventStreamScreen] ConnectionManager not available: $e');
      }
    }

    final client = _connectionManager?.activeRuntimeClient;
    if (client == null) return;

    _eventStream = client.agentEventStream;
    _subscription = _eventStream?.listen(_onEvent);
  }
  void _onEvent(AgentEvent event) {
    if (_paused || !mounted) return;
    setState(() {
      _events.insert(0, event);
      if (_events.length > _maxEvents) {
        _events.removeLast();
      }
    });
  }

  void _togglePause() {
    setState(() => _paused = !_paused);
  }

  void _clearEvents() {
    setState(_events.clear);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  Color _eventColor(String label) {
    if (label.startsWith('run.failed')) return Colors.red;
    if (label.startsWith('run.completed')) return Colors.green;
    if (label.startsWith('tool.started')) return Colors.blue;
    if (label.startsWith('tool.completed')) return Colors.teal;
    if (label.startsWith('reasoning')) return Colors.deepPurple;
    return Colors.grey;
  }

  IconData _eventIcon(String label) {
    if (label.startsWith('tool.started')) return Icons.build_circle_outlined;
    if (label.startsWith('tool.completed')) {
      return Icons.check_circle_outline;
    }
    if (label.startsWith('reasoning')) return Icons.psychology_outlined;
    if (label.startsWith('message.delta')) return Icons.chat_bubble_outline;
    if (label.startsWith('run.completed')) {
      return Icons.task_alt_outlined;
    }
    if (label.startsWith('run.failed')) return Icons.error_outline;
    return Icons.circle_outlined;
  }

  String _eventSummary(AgentEvent event) {
    final s = switch (event) {
      AgentToolStarted(tool: var t, preview: var p) =>
        p != null ? '$t: $p' : t,
      AgentToolCompleted(tool: var t) => t,
      AgentRunCompleted() => 'Run finished',
      AgentRunFailed(error: var e) => e,
      _ => '',
    };
    return s.isEmpty ? event.eventTypeLabel : s;
  }

  @override
  Widget build(BuildContext context) {
    if (_connectionManager == null ||
        _connectionManager!.activeRuntimeClient == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Event Stream')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.stream, size: 48, color: Colors.grey.shade400),
              const SizedBox(height: 16),
              Text(
                'No agent runtime connected',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.grey.shade600,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'Connect to a Hermes or OpenClaw runtime to see live events.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey.shade500,
                    ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Event Stream'),
        actions: [
          IconButton(
            icon: Icon(_paused ? Icons.play_arrow : Icons.pause),
            tooltip: _paused ? 'Resume' : 'Pause',
            onPressed: _togglePause,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Clear',
            onPressed: _events.isEmpty ? null : _clearEvents,
          ),
        ],
      ),
      body: _events.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.stream, size: 48, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  Text(
                    'Waiting for agent events…',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: _events.length,
              itemBuilder: (context, index) {
                final event = _events[index];
                final label = event.eventTypeLabel;
                final color = _eventColor(label);
                return ListTile(
                  dense: true,
                  leading: CircleAvatar(
                    radius: 16,
                    backgroundColor: color.withValues(alpha: 0.15),
                    child:
                        Icon(_eventIcon(label), size: 18, color: color),
                  ),
                  title: Text(
                    label,
                    style: TextStyle(color: color, fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(_eventSummary(event)),
                  trailing: Text(
                    _formatTime(event.timestamp),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                );
              },
            ),
    );
  }

  String _formatTime(double secondsSinceEpoch) {
    final dt = DateTime.fromMillisecondsSinceEpoch(
      (secondsSinceEpoch * 1000).round(),
    );
    return '${dt.hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')}:'
        '${dt.second.toString().padLeft(2, '0')}';
  }
}
