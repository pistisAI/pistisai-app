import 'package:pistisai/di/locator.dart' as di;
import 'package:pistisai/screens/agents/agents_screen.dart';
import 'package:pistisai/screens/cron/cron_jobs_screen.dart';
import 'package:pistisai/screens/skills/skills_screen.dart';
import 'package:pistisai/services/cron_service.dart';
import 'package:pistisai/models/cron_job.dart';
import 'package:pistisai/services/popout/popout_manager.dart';
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
    testWidgets('renders empty state when no backend available', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: AgentsScreen(),
        ),
      );

      await tester.pump();

      // Tab controller with 3 tabs renders.
      expect(find.byType(Tab), findsNWidgets(3));
    });
  });

  group('SkillsScreen', () {
    testWidgets('renders empty state when no skills directory available', (tester) async {
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

      // Tab controller with 3 tabs renders.
      expect(find.byType(Tab), findsNWidgets(3));
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

      // CronJobsScreen loads mock jobs.
      expect(find.text('Cron Jobs'), findsOneWidget);
    });
  });
}
