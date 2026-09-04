import 'package:pistisai/di/locator.dart' as di;
import 'package:pistisai/models/cron_job.dart';
import 'package:pistisai/screens/agents/agents_screen.dart';
import 'package:pistisai/screens/cron/cron_jobs_screen.dart';
import 'package:pistisai/screens/skills/skills_screen.dart';
import 'package:pistisai/services/cron_service.dart';
import 'package:pistisai/services/popout/popout_manager.dart';
import 'package:pistisai/services/skill_service.dart';
import 'package:pistisai/services/subagent_registry_service.dart';
import 'package:pistisai/widgets/common/loading_skeleton.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Fake CronService that resolves with an empty list after a microtask, so the
/// screen shows its loading skeleton at first pump before settling to empty.
class _FakeCronService extends CronService {
  @override
  Future<List<CronJob>> listJobs() async {
    await Future<void>.delayed(Duration.zero);
    return [];
  }
}

class _FakeSubagentRegistry extends SubagentRegistryService {
  final List<Subagent> items = [];

  @override
  Future<List<Subagent>> listSubagents(
      {String? status, String? agentId}) async {
    return List<Subagent>.from(items);
  }

  @override
  Future<Subagent?> registerSubagent({
    required String subagentId,
    required String agentId,
    String? label,
    String? task,
  }) async {
    final existing = items.indexWhere((s) => s.subagentId == subagentId);
    final created = Subagent(
      subagentId: subagentId,
      agentId: agentId,
      label: label,
      task: task,
      status: SubagentStatus.pending,
      createdAt: DateTime.now(),
    );
    if (existing >= 0) {
      items[existing] = created;
    } else {
      items.add(created);
    }
    return created;
  }
}

void main() {
  setUpAll(() {
    SharedPreferences.setMockInitialValues({});
    if (di.serviceLocator.isRegistered<PopOutManager>()) {
      di.serviceLocator.unregister<PopOutManager>();
    }
    di.serviceLocator.registerSingleton<PopOutManager>(PopOutManager());
    if (di.serviceLocator.isRegistered<CronService>()) {
      di.serviceLocator.unregister<CronService>();
    }
    di.serviceLocator.registerSingleton<CronService>(_FakeCronService());
  });

  group('AgentsScreen', () {
    testWidgets('renders empty state when no backend available',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: AgentsScreen(),
        ),
      );

      await tester.pump();

      expect(find.byType(Tab), findsNWidgets(3));
    });

    testWidgets('add agent opens a register dialog instead of coming soon',
        (tester) async {
      final registry = _FakeSubagentRegistry();
      if (di.serviceLocator.isRegistered<SubagentRegistryService>()) {
        di.serviceLocator.unregister<SubagentRegistryService>();
      }
      di.serviceLocator.registerSingleton<SubagentRegistryService>(registry);
      addTearDown(() {
        if (di.serviceLocator.isRegistered<SubagentRegistryService>()) {
          di.serviceLocator.unregister<SubagentRegistryService>();
        }
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: AgentsScreen(),
        ),
      );
      await tester.pump();

      await tester.tap(find.byTooltip('Add Agent'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('Register Agent'), findsOneWidget);
      expect(find.textContaining('coming soon'), findsNothing);

      await tester.enterText(find.byType(TextField).first, 'research-bot-1');
      await tester.tap(find.text('Register'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(registry.items, hasLength(1));
      expect(registry.items.first.subagentId, 'research-bot-1');
      expect(find.text('research-bot-1'), findsWidgets);
    });
  });

  group('SkillsScreen', () {
    testWidgets('renders empty state when no skills directory available',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: const SizedBox(
            width: 1200,
            height: 800,
            child: SkillsScreen(),
          ),
        ),
      );

      await tester.pump();

      expect(find.byType(Tab), findsNWidgets(3));
    });

    testWidgets('register skill opens a form instead of coming soon',
        (tester) async {
      if (di.serviceLocator.isRegistered<SkillService>()) {
        di.serviceLocator.unregister<SkillService>();
      }
      di.serviceLocator.registerSingleton<SkillService>(
        SkillService(skillsDir: '/tmp/pistisai-skill-dialog'),
      );
      addTearDown(() {
        if (di.serviceLocator.isRegistered<SkillService>()) {
          di.serviceLocator.unregister<SkillService>();
        }
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: SizedBox(
            width: 1200,
            height: 800,
            child: SkillsScreen(),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.byTooltip('Register Skill'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('Register Skill'), findsWidgets);
      expect(find.textContaining('coming soon'), findsNothing);
      expect(find.text('Name'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pump();
    });
  });

  group('CronJobsScreen', () {
    testWidgets('shows scheduled tasks after loading', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: CronJobsScreen(),
        ),
      );

      expect(find.byType(LoadingSkeleton), findsWidgets);
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Cron Jobs'), findsOneWidget);
    });
  });
}
