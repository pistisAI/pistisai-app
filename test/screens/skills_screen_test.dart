import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pistisai/di/locator.dart' as di;
import 'package:pistisai/l10n/app_localizations.dart';
import 'package:pistisai/screens/skills/skills_screen.dart';
import 'package:pistisai/services/skill_service.dart';

void main() {
  late Directory skillsDir;

  setUp(() {
    skillsDir = Directory.systemTemp.createTempSync('pistisai-skills-858-');
    final skill = Directory('${skillsDir.path}/research/web-search')
      ..createSync(recursive: true);
    File('${skill.path}/SKILL.md').writeAsStringSync(
      '---\nname: web-search\ndescription: Search the web\n---\n',
    );
    if (di.serviceLocator.isRegistered<SkillService>()) {
      di.serviceLocator.unregister<SkillService>();
    }
    di.serviceLocator.registerSingleton<SkillService>(
        SkillService(skillsDir: skillsDir.path));
  });

  tearDown(() {
    if (di.serviceLocator.isRegistered<SkillService>()) {
      di.serviceLocator.unregister<SkillService>();
    }
    skillsDir.deleteSync(recursive: true);
  });

  Future<void> pumpSkills(WidgetTester tester) async {
    await tester.runAsync(() async {
      await tester.pumpWidget(
        const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: SkillsScreen(),
        ),
      );
      // Let the real file-system scan complete.
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.pump();
  }

  // #858: the enable switch only changed an in-memory list and reported
  // "enabled/disabled"; the Management tab had switches with empty handlers;
  // "uses" counts were skill counts or always 0.
  testWidgets('skill cards have no fake enable switch or usage stats',
      (tester) async {
    await pumpSkills(tester);

    expect(find.text('web-search'), findsOneWidget);
    expect(find.byType(Switch), findsNothing);
    expect(find.textContaining('Uses'), findsNothing);
    expect(find.textContaining('Avg Time'), findsNothing);
    expect(find.textContaining('Last Used'), findsNothing);
    expect(find.text('1 file'), findsOneWidget);
    expect(find.byIcon(Icons.open_in_new), findsNothing);
  });

  testWidgets('no inert Management tab; categories count skills, not uses',
      (tester) async {
    await pumpSkills(tester);

    expect(find.text('Management'), findsNothing);
    expect(find.byType(Tab), findsNWidgets(2));

    await tester.tap(find.text('Categories'));
    await tester.pumpAndSettle();

    expect(find.text('Skills by category'), findsOneWidget);
    expect(find.text('1 skill'), findsOneWidget);
    expect(find.textContaining('use'), findsNothing);
    expect(find.text('Top Performing Skills'), findsNothing);
  });
}
