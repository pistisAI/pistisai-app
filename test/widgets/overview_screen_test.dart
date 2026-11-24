import 'package:pistisai/l10n/app_localizations.dart';
import 'package:pistisai/di/locator.dart' as di;
import 'package:pistisai/screens/dashboard/overview_screen.dart';
import 'package:pistisai/services/agent_runtime/agent_runtime_client.dart';
import 'package:pistisai/services/agent_runtime/hermes_runtime_client.dart';
import 'package:pistisai/services/connection_manager_service.dart';
import 'package:pistisai/services/hermes/hermes_streaming_service.dart';
import 'package:pistisai/services/voice/voice_conversation_service.dart';
import 'package:pistisai/services/voice/local_voice_input_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeOverviewConnectionManager extends ConnectionManagerService {
  _FakeOverviewConnectionManager()
      : super(
          hermesStreamingService: HermesStreamingService(),
        );

  final AgentRuntimeClient _client = HermesRuntimeClient(
    baseUrl: 'http://runtime.example.com:9000',
    apiKey: 'test-key-0123456789abcdef',
  );

  @override
  Future<bool> testConnection() async => true;

  @override
  BackendType? get currentBackend => BackendType.hermes;

  @override
  AgentRuntimeClient? get activeRuntimeClient => _client;

  @override
  bool get isConnected => true;

  @override
  List<String> get availableModels => const <String>['model-a', 'model-b'];

  @override
  Map<String, dynamic> getGatewayStatus() => <String, dynamic>{
        'state': 'connected',
        'isRunning': true,
        'isConnected': true,
        'backend': 'hermes',
        'backendLabel': 'Hermes Agent',
        'hermes': <String, dynamic>{
          'state': 'running',
          'isRunning': true,
        },
      };
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues(<String, Object>{});

  late VoiceConversationService voiceService;
  late _FakeOverviewConnectionManager connectionManager;

  setUp(() {
    voiceService = VoiceConversationService();
    connectionManager = _FakeOverviewConnectionManager();

    if (di.serviceLocator.isRegistered<VoiceConversationService>()) {
      di.serviceLocator.unregister<VoiceConversationService>();
    }
    di.serviceLocator.registerSingleton<VoiceConversationService>(
      voiceService,
    );
  });

  tearDown(() async {
    if (di.serviceLocator.isRegistered<VoiceConversationService>()) {
      di.serviceLocator.unregister<VoiceConversationService>();
    }
    voiceService.dispose();
  });

  Future<void> pumpOverview(WidgetTester tester) async {
    final localVoice = LocalVoiceInputService(
      voiceConversationService: voiceService,
    );
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) {
            return MultiProvider(
              providers: [
                ChangeNotifierProvider<ConnectionManagerService>.value(
                  value: connectionManager,
                ),
                ChangeNotifierProvider<VoiceConversationService>.value(
                  value: voiceService,
                ),
                ChangeNotifierProvider<LocalVoiceInputService>.value(
                  value: localVoice,
                ),
              ],
              child: const OverviewScreen(),
            );
          },
        ),
      ],
    );

    await tester.pumpWidget(MaterialApp.router(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router));

    await tester.pumpAndSettle();
  }

  // Re-enabled — DI registered in setUp.
  testWidgets('overview voice section exposes demo controls', (tester) async {
    await pumpOverview(tester);

    expect(find.text('Voice Companion'), findsOneWidget);
    // VoiceConversationStatusCard and OpenVoiceUIControlPanel should render
    // since VoiceConversationService is registered in GetIt.
    expect(find.text('OpenVoiceUI Control'), findsOneWidget);
  });

  testWidgets('overview shows the configured runtime, not placeholders (#857)',
      (tester) async {
    await pumpOverview(tester);

    // The saved runtime URL, not the built-in default.
    expect(find.text('http://runtime.example.com:9000'), findsOneWidget);
    expect(find.text('Hermes Agent'), findsWidgets);
    // The key is reported as present, never partially displayed.
    expect(find.text('Set'), findsOneWidget);
    expect(find.textContaining('test-key'), findsNothing);
    expect(find.text('Connected'), findsOneWidget);
    expect(find.text('Models reported'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);

    // Fields the connection manager never provides are gone.
    expect(find.text('Default Session Key'), findsNothing);
    expect(find.text('main'), findsNothing);
    expect(find.text('Instances'), findsNothing);
    expect(find.text('Sessions'), findsNothing);
    expect(find.text('Uptime'), findsNothing);
    expect(find.text('Unknown'), findsNothing);
  });
}
