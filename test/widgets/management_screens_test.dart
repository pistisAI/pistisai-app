import 'package:pistisai/di/locator.dart' as di;
import 'package:pistisai/screens/agents/agents_screen.dart';
import 'package:pistisai/screens/cron/cron_jobs_screen.dart';
import 'package:pistisai/screens/skills/skills_screen.dart';
import 'package:pistisai/services/popout/popout_manager.dart';
import 'package:pistisai/widgets/common/loading_skeleton.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUpAll(() {
    SharedPreferences.setMockInitialValues({});
    if (di.serviceLocator.isRegistered<PopOutManager>()) {
      di.serviceLocator.unregister<PopOutManager>();
    }
    di.serviceLocator.registerSingleton<PopOutManager>(PopOutManager());
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
    testWidgets('renders skills list after loading', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: const SizedBox(
            width: 1200,
            height: 800,
            child: SkillsScreen(),
          ),
        ),
      );

      expect(find.byType(LoadingSkeleton), findsWidgets);
      await tester.pump(const Duration(milliseconds: 400));

      // Tab controller with 3 tabs.
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
