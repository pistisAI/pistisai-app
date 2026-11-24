// Regression tests for #860 (chat tools sheet, Brain insights) and #861
// (roadmap links, GUI automation execute, setup wizard wording).
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pistisai/components/brain_insight_widget.dart';
import 'package:pistisai/database/drift_local_brain.dart';
import 'package:pistisai/l10n/app_localizations.dart';
import 'package:pistisai/screens/construction_screen.dart';
import 'package:pistisai/screens/gui_automation_screen.dart';
import 'package:pistisai/screens/home/chat_tools_panel.dart';
import 'package:pistisai/screens/onboarding/steps/completion_step.dart';
import 'package:pistisai/services/agent_action_audit_service.dart';
import 'package:pistisai/services/agent_runtime/agent_runtime_client.dart';
import 'package:pistisai/services/auth_service.dart';
import 'package:pistisai/services/onboarding/setup_wizard_service.dart';
import 'package:pistisai/services/provider_configuration_manager.dart';
import 'package:pistisai/services/provider_discovery_service.dart';
import 'package:pistisai/services/setup_status_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher_platform_interface/link.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

Widget _app(Widget home, {Locale? locale}) => MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: home,
    );

const _allCapabilities = RuntimeCapabilityManifest(
  chatStreaming: true,
  agentEvents: true,
  toolRequests: true,
  desktopActionRequests: true,
  voice: true,
);

class _RecordingUrlLauncher extends UrlLauncherPlatform {
  _RecordingUrlLauncher({required this.result});

  final bool result;
  final List<String> launched = <String>[];

  @override
  LinkDelegate? get linkDelegate => null;

  @override
  Future<bool> canLaunch(String url) async => result;

  @override
  Future<bool> launchUrl(String url, LaunchOptions options) async {
    launched.add(url);
    return result;
  }
}

class _ThrowingAudit extends AgentActionAuditService {
  _ThrowingAudit(LocalBrain db) : super(database: db);

  @override
  Future<List<AgentActionAuditEntry>> list({int limit = 500}) =>
      Future<List<AgentActionAuditEntry>>.error(StateError('read failed'));
}

class _FakeAuthService extends ChangeNotifier implements AuthService {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('chat tools sheet (#860)', () {
    test('nothing is available without a connected agent', () {
      final tools = deriveChatTools(
        agentConnected: false,
        capabilities: _allCapabilities,
      );
      expect(tools, hasLength(ChatTool.values.length));
      expect(tools.where((t) => t.isAvailable), isEmpty);
      expect(
        tools.map((t) => t.state).toSet(),
        {ChatToolState.needsAgent},
      );
    });

    test('availability follows the runtime capability manifest', () {
      final tools = deriveChatTools(
        agentConnected: true,
        capabilities: const RuntimeCapabilityManifest(
          chatStreaming: true,
          agentEvents: true,
          toolRequests: true,
          desktopActionRequests: false,
          voice: false,
        ),
      );
      final byTool = {for (final t in tools) t.tool: t.state};
      expect(byTool[ChatTool.desktop], ChatToolState.notReported);
      expect(byTool[ChatTool.vision], ChatToolState.notReported);
      expect(byTool[ChatTool.voice], ChatToolState.notReported);
      expect(byTool[ChatTool.webSearch], ChatToolState.available);
      expect(byTool[ChatTool.code], ChatToolState.available);
    });

    test('connected without a manifest is not reported as available', () {
      final tools = deriveChatTools(agentConnected: true);
      expect(tools.where((t) => t.isAvailable), isEmpty);
    });

    testWidgets('panel shows no tool as available while disconnected',
        (tester) async {
      await tester.pumpWidget(_app(Scaffold(
        body: ChatToolsPanel(
          agentName: 'Agent',
          tools: deriveChatTools(agentConnected: false),
        ),
      )));
      expect(find.byIcon(Icons.check_circle), findsNothing);
      expect(find.text('available'), findsNothing);
      expect(find.text('unavailable'), findsNWidgets(ChatTool.values.length));
      expect(find.textContaining('Available offline'), findsNothing);
    });

    testWidgets('panel marks reported tools available when connected',
        (tester) async {
      await tester.pumpWidget(_app(Scaffold(
        body: ChatToolsPanel(
          agentName: 'Agent',
          tools: deriveChatTools(
            agentConnected: true,
            capabilities: _allCapabilities,
          ),
        ),
      )));
      expect(find.byIcon(Icons.check_circle),
          findsNWidgets(ChatTool.values.length));
    });
  });

  group('Brain insights (#860)', () {
    late LocalBrain db;
    late AgentActionAuditService audit;

    setUp(() {
      db = LocalBrain.withExecutor(NativeDatabase.memory());
      audit = AgentActionAuditService(database: db);
    });

    tearDown(() async {
      await db.close();
    });

    Future<void> pumpJournal(WidgetTester tester) async {
      await tester.pumpWidget(_app(Scaffold(
        body: BrainInsightWidget(
          audit: audit,
          refreshInterval: const Duration(hours: 1),
        ),
      )));
      // Drift runs its queries off the fake-async zone.
      await tester.runAsync(() => Future<void>.delayed(
            const Duration(milliseconds: 100),
          ));
      await tester.pump();
    }

    testWidgets('shows recorded agent actions, not a fixed placeholder',
        (tester) async {
      await tester.runAsync(() => audit.record(
            action: 'tool.completed',
            dataTouched: 'tool:web_search',
            authorizationStatus: AgentAuditAuthorization.autoAllowed,
            outcome: AgentAuditOutcome.success,
          ));
      await pumpJournal(tester);

      expect(find.text('tool.completed'), findsOneWidget);
      expect(find.text('HIGH SPEED (RAM)'), findsNothing);
      expect(find.text('No internal logs recorded yet.'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('empty journal says so', (tester) async {
      await pumpJournal(tester);
      expect(
        find.text(
            'No agent actions recorded yet. Tool use in chat appears here.'),
        findsOneWidget,
      );
      expect(find.text('HIGH SPEED (RAM)'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('a read error is shown as an error, not as "no logs"',
        (tester) async {
      audit = _ThrowingAudit(db);
      await pumpJournal(tester);
      expect(find.text('Could not read the activity journal.'), findsOneWidget);
      expect(
        find.text(
            'No agent actions recorded yet. Tool use in chat appears here.'),
        findsNothing,
      );
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('roadmap links (#861)', () {
    late UrlLauncherPlatform original;

    setUp(() => original = UrlLauncherPlatform.instance);
    tearDown(() => UrlLauncherPlatform.instance = original);

    testWidgets('a link card opens its URL', (tester) async {
      final launcher = _RecordingUrlLauncher(result: true);
      UrlLauncherPlatform.instance = launcher;
      tester.view.physicalSize = const Size(1400, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_app(const ConstructionScreen()));
      await tester.tap(find.text('Documentation'));
      await tester.pumpAndSettle();

      expect(launcher.launched, hasLength(1));
      expect(find.textContaining('Opening '), findsNothing);
    });

    testWidgets('a link that cannot open reports the failure', (tester) async {
      UrlLauncherPlatform.instance = _RecordingUrlLauncher(result: false);
      tester.view.physicalSize = const Size(1400, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_app(const ConstructionScreen()));
      await tester.tap(find.text('Documentation'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Could not open'), findsOneWidget);
    });
  });

  testWidgets('GUI automation offers no unapproved Execute action (#861)',
      (tester) async {
    await tester.pumpWidget(_app(const GuiAutomationScreen()));
    await tester.pump();

    expect(find.text('Execute'), findsNothing);
    expect(find.byType(TextField), findsNothing);
    expect(
      find.text('Running actions from this screen is not available yet.'),
      findsOneWidget,
    );
  });

  testWidgets('wizard final step does not claim setup is saved (#861)',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final wizard = SetupWizardService(
      ProviderDiscoveryService(),
      SetupStatusService(
        authService: _FakeAuthService(),
        storage: InMemorySetupStatusStorage(),
      ),
      ProviderConfigurationManager(),
    );
    await tester.pumpWidget(
      ChangeNotifierProvider<SetupWizardService>.value(
        value: wizard,
        child: _app(const Scaffold(body: CompletionStep())),
      ),
    );
    await tester.pump();

    expect(find.text("You're All Set!"), findsNothing);
    expect(find.textContaining('configured and ready'), findsNothing);
    expect(find.text('Almost done'), findsOneWidget);
  });
}
