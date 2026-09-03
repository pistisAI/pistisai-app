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

  test('skillFolderSlug lowercases and strips punctuation', () {
    expect(skillFolderSlug('Summarize Selection!'), 'summarize-selection');
    expect(skillFolderSlug('   '), 'skill');
  });

  test('registerSkill writes SKILL.md that getSkills can parse', () async {
    final created = await service.registerSkill(
      name: 'Summarize Selection',
      description: 'Turns highlighted text into a short summary.',
      category: 'Writing',
    );

    expect(created.name, 'Summarize Selection');
    expect(created.category, 'writing');

    final skillFile =
        File('${tempDir.path}/writing/summarize-selection/SKILL.md');
    expect(await skillFile.exists(), isTrue);

    final skills = await service.getSkills();
    expect(skills, hasLength(1));
    expect(skills.first.name, 'Summarize Selection');
    expect(
      skills.first.description,
      'Turns highlighted text into a short summary.',
    );
    expect(skills.first.category, 'writing');
  });

  test('registerSkill rejects empty name or description', () async {
    expect(
      () => service.registerSkill(name: '  ', description: 'desc'),
      throwsArgumentError,
    );
    expect(
      () => service.registerSkill(name: 'ok', description: ''),
      throwsArgumentError,
    );
  });
}
