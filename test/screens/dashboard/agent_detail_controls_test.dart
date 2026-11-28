import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pistisai/l10n/app_localizations.dart';
import 'package:pistisai/screens/dashboard/agent_detail_screen.dart';
import 'package:pistisai/services/agent_lifecycle_service.dart';
import 'package:pistisai/services/connection_manager_service.dart';
import 'package:provider/provider.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// Stands in for an open gateway channel. Requests sent on it go nowhere,
/// which the service tolerates and then times out on.
class _GatewayChannel implements WebSocketChannel {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Hermes connects over HTTP with no gateway channel; a gateway runtime
/// (OpenClaw) has one.
class _FakeConnection extends ChangeNotifier
    implements ConnectionManagerService {
  _FakeConnection({required this.hermes})
      : _channel = hermes ? null : _GatewayChannel();

  final bool hermes;
  final WebSocketChannel? _channel;
  final StreamController<Map<String, dynamic>> _messages =
      StreamController<Map<String, dynamic>>.broadcast();

  @override
  BackendType? get currentBackend => hermes ? BackendType.hermes : null;

  @override
  bool get isConnected => true;

  @override
  bool isGatewayHealthy() => true;

  @override
  WebSocketChannel? get wsChannel => _channel;

  @override
  Stream<Map<String, dynamic>> get messageStream => _messages.stream;

  @override
  void dispose() {
    _messages.close();
    super.dispose();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  Future<void> pumpDetail(
    WidgetTester tester, {
    required bool hermes,
    Locale locale = const Locale('en'),
  }) async {
    final connection = _FakeConnection(hermes: hermes);
    final service = AgentLifecycleService(connectionManager: connection);
    addTearDown(() {
      service.dispose();
      connection.dispose();
    });
    // A known agent, as a status event reports it.
    service.handleGatewayMessage(<String, dynamic>{
      'type': 'event',
      'event': 'agent.status',
      'payload': <String, dynamic>{
        'agentId': 'a1',
        'name': 'Agent One',
        'status': 'idle',
      },
    });
    await tester.pumpWidget(
      ChangeNotifierProvider<AgentLifecycleService>.value(
        value: service,
        child: MaterialApp(
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: const [Locale('en'), Locale('fr')],
          home: const AgentDetailScreen(agentId: 'a1'),
        ),
      ),
    );
    await tester.pump();
  }

  group('AgentDetailScreen agent controls (#1042)', () {
    testWidgets('Hermes hides Start, Stop and Restart and says why',
        (tester) async {
      await pumpDetail(tester, hermes: true);

      expect(find.text('Agent One'), findsWidgets);
      expect(find.text('Start'), findsNothing);
      expect(find.text('Stop'), findsNothing);
      expect(find.text('Restart'), findsNothing);
      expect(
        find.text('Agent control is not available for this runtime yet'),
        findsOneWidget,
      );
    });

    testWidgets('the not-available message is translated under fr',
        (tester) async {
      await pumpDetail(tester, hermes: true, locale: const Locale('fr'));

      expect(find.text('Démarrer'), findsNothing);
      expect(find.text('Redémarrer'), findsNothing);
      expect(
        find.text(
          "Le contrôle des agents n'est pas encore disponible pour cet "
          "environnement d'exécution",
        ),
        findsOneWidget,
      );
      expect(
        find.text('Agent control is not available for this runtime yet'),
        findsNothing,
      );
    });

    testWidgets('a gateway runtime keeps Start, Stop and Restart',
        (tester) async {
      await pumpDetail(tester, hermes: false);

      expect(find.text('Start'), findsOneWidget);
      expect(find.text('Stop'), findsOneWidget);
      expect(find.text('Restart'), findsOneWidget);
      expect(
        find.byKey(const Key('agent-controls-not-available')),
        findsNothing,
      );

      // Let the unanswered status request time out.
      await tester.pump(const Duration(seconds: 11));
    });
  });
}
