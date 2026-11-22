import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pistisai/l10n/app_localizations.dart';
import 'package:pistisai/screens/settings/llm_provider_settings_screen.dart';
import 'package:pistisai/services/connection_manager_service.dart';
import 'package:pistisai/services/hermes/hermes_streaming_service.dart';
import 'package:provider/provider.dart';

class _FakeConnectionManager extends ConnectionManagerService {
  _FakeConnectionManager({required this.connected})
      : super(
          hermesStreamingService: HermesStreamingService(),
          autoDetectOnInitialize: false,
        );

  final bool connected;

  @override
  bool get isConnected => connected;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pumpScreen(WidgetTester tester, bool connected) async {
    final service = _FakeConnectionManager(connected: connected);
    addTearDown(service.dispose);
    await tester.pumpWidget(
      ChangeNotifierProvider<ConnectionManagerService>.value(
        value: service,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: const [Locale('en'), Locale('fr')],
          home: const LLMProviderSettingsScreen(),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('reports disconnected when the runtime is not connected',
      (tester) async {
    await pumpScreen(tester, false);
    expect(find.text('Disconnected'), findsOneWidget);
    expect(find.byIcon(Icons.error_outline), findsOneWidget);
    expect(find.byIcon(Icons.check_circle), findsNothing);
  });

  testWidgets('reports connected when the runtime is connected',
      (tester) async {
    await pumpScreen(tester, true);
    expect(find.text('Connected'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle), findsOneWidget);
  });
}
