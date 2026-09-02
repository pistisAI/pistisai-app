import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pistisai/services/skill_service.dart';

void main() {
  late Directory tempDir;
  late SkillService service;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('pistisai-skills-');
    service = SkillService(skillsDir: tempDir.path);
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('registerSkill writes SKILL.md and is discovered', () async {
    final created = await service.registerSkill(
      name: 'Summarize Notes',
      description: "Condenses a user's notes",
      category: 'Writing Tools',
    );

    expect(created.name, 'Summarize Notes');
    expect(created.category, 'writing-tools');
    expect(created.enabled, isTrue);

    final skills = await service.getSkills();
    expect(skills, hasLength(1));
    expect(skills.single.name, 'Summarize Notes');
    expect(skills.single.description, "Condenses a user's notes");
  });

  test('setSkillEnabled persists a disabled marker', () async {
    await service.registerSkill(
      name: 'lookup',
      description: 'Look things up',
      category: 'utilities',
    );

    await service.setSkillEnabled(
      name: 'lookup',
      category: 'utilities',
      enabled: false,
    );
    expect((await service.getSkills()).single.enabled, isFalse);

    await service.setSkillEnabled(
      name: 'lookup',
      category: 'utilities',
      enabled: true,
    );
    expect((await service.getSkills()).single.enabled, isTrue);
  });

  test('sanitizeSkillPathSegment strips unsafe characters', () {
    expect(sanitizeSkillPathSegment('Hello World!'), 'hello-world');
    expect(sanitizeSkillPathSegment('  '), isEmpty);
  });
}
