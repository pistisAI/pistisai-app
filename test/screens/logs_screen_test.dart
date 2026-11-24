import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pistisai/di/locator.dart' as di;
import 'package:pistisai/l10n/app_localizations.dart';
import 'package:pistisai/models/log_entry.dart';
import 'package:pistisai/screens/logs/logs_screen.dart';
import 'package:pistisai/services/logging_service.dart';

class _FailingLoggingService extends LoggingService {
  _FailingLoggingService() : super(logDir: '.');

  @override
  Future<List<LogEntry>> getAllLogs({int limitPerSource = 100}) async {
    throw StateError('log directory unreadable');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    if (di.serviceLocator.isRegistered<LoggingService>()) {
      di.serviceLocator.unregister<LoggingService>();
    }
  });

  Future<void> pumpScreen(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: LogsScreen(),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  group('LogsScreen (#857)', () {
    testWidgets('shows a load failure instead of an empty list',
        (tester) async {
      di.serviceLocator.registerSingleton<LoggingService>(
        _FailingLoggingService(),
      );

      await pumpScreen(tester);

      expect(
        find.textContaining('Could not load logs'),
        findsWidgets,
      );
      expect(find.textContaining('log directory unreadable'), findsWidgets);
      expect(find.text('No logs available'), findsNothing);
    });

    testWidgets('says the log service is unavailable when it is missing',
        (tester) async {
      await pumpScreen(tester);

      expect(find.text('Log service unavailable'), findsOneWidget);
      expect(find.text('No logs available'), findsNothing);
    });
  });
}
