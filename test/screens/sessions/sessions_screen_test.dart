import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pistisai/di/locator.dart' as di;
import 'package:pistisai/l10n/app_localizations.dart';
import 'package:pistisai/models/session.dart';
import 'package:pistisai/screens/sessions/sessions_screen.dart';
import 'package:pistisai/services/session_service.dart';

class _FakeSessionService implements SessionService {
  _FakeSessionService({this.sessions = const [], this.error});

  final List<SessionData> sessions;
  final Object? error;

  @override
  Future<List<SessionData>> listSessions({int limit = 50}) async {
    if (error != null) throw error!;
    return sessions;
  }

  @override
  Future<bool> terminate(String id) async => true;
}

Future<void> _pump(WidgetTester tester, SessionService service) async {
  if (di.serviceLocator.isRegistered<SessionService>()) {
    di.serviceLocator.unregister<SessionService>();
  }
  di.serviceLocator.registerSingleton<SessionService>(service);
  addTearDown(() => di.serviceLocator.unregister<SessionService>());

  tester.view.physicalSize = const Size(1400, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    const MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: SessionsScreen(),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  const agent = SessionData(
    id: '20261120_ab12',
    type: 'agent',
    userOrAgent: 'Morning planning',
    preview: 'Here is your agenda',
    lastActive: '5m ago',
  );
  const cron = SessionData(
    id: 'cron_daily_1',
    type: 'cron',
    userOrAgent: 'Daily briefing',
    lastActive: '2h ago',
  );

  testWidgets('agent sessions show in the first tab, cron in the second',
      (tester) async {
    await _pump(tester, _FakeSessionService(sessions: const [agent, cron]));

    expect(find.text('Morning planning'), findsOneWidget);
    expect(find.text('Here is your agenda'), findsOneWidget);
    expect(find.text('5m ago'), findsOneWidget);
    expect(find.text('Daily briefing'), findsNothing);

    await tester.tap(find.text('Scheduled'));
    await tester.pumpAndSettle();

    expect(find.text('Daily briefing'), findsOneWidget);
    expect(find.text('Morning planning'), findsNothing);
  });

  testWidgets('a failing hermes command shows an error, not "No Sessions"',
      (tester) async {
    await _pump(
      tester,
      _FakeSessionService(error: SessionServiceException('hermes missing')),
    );

    expect(find.textContaining('hermes missing'), findsWidgets);
    expect(find.text('No Sessions'), findsNothing);
  });
}
