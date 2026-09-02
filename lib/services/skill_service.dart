import 'dart:io';

import 'package:flutter/foundation.dart';

/// Parsed skill metadata from a SKILL.md file.
class SkillInfo {
  final String name;
  final String description;
  final String category;
  final bool enabled;
  final DateTime? lastModified;
  final int fileCount;

  const SkillInfo({
    required this.name,
    required this.description,
    required this.category,
    this.enabled = true,
    this.lastModified,
    this.fileCount = 1,
  });
}

/// Reads the local Hermes skills directory and parses skill metadata.
///
/// Skills live at `~/.hermes/skills/<category>/<name>/SKILL.md`.
/// Each SKILL.md has YAML frontmatter with name, description, tags.
class SkillService {
  final String _skillsDir;

  SkillService({String? skillsDir})
      : _skillsDir = skillsDir ?? _defaultSkillsDir();

  static String _defaultSkillsDir() {
    try {
      final home = Platform.environment['LOCALAPPDATA'] ??
          Platform.environment['HOME'] ??
          Platform.environment['USERPROFILE'] ??
          '.';
      return '$home/hermes/skills';
    } catch (_) {
      return '.';
    }
  }

  /// Returns all discovered skills with metadata.
  Future<List<SkillInfo>> getSkills() async {
    final dir = Directory(_skillsDir);
    if (!await dir.exists()) {
      debugPrint('[SkillService] Skills directory not found: $_skillsDir');
      return [];
    }

    final skills = <SkillInfo>[];
    try {
      await for (final categoryEntity in dir.list()) {
        if (categoryEntity is! Directory) continue;
        final categoryName =
            categoryEntity.path.split(Platform.pathSeparator).last;

        await for (final skillEntity in categoryEntity.list()) {
          if (skillEntity is! Directory) continue;
          final skillName = skillEntity.path.split(Platform.pathSeparator).last;

          final skillMd = File('${skillEntity.path}/SKILL.md');
          if (!await skillMd.exists()) continue;

          try {
            final content = await skillMd.readAsString();
            final metadata = _parseFrontmatter(content);
            final fileCount = await _countFiles(skillEntity);
            final disabledMarker =
                File('${skillEntity.path}${Platform.pathSeparator}.disabled');

            skills.add(SkillInfo(
              name: metadata['name'] ?? skillName,
              description: metadata['description'] ?? '',
              category: categoryName,
              enabled: !await disabledMarker.exists(),
              lastModified: await _lastModified(skillMd),
              fileCount: fileCount,
            ));
          } catch (e) {
            debugPrint('[SkillService] Error parsing $skillName: $e');
          }
        }
      }
    } catch (e) {
      debugPrint('[SkillService] Error scanning skills dir: $e');
    }

    skills.sort((a, b) => a.name.compareTo(b.name));
    return skills;
  }

  /// Parse YAML-like frontmatter from a SKILL.md file.
  /// Looks for `---` delimited blocks and extracts key: value pairs.
  Map<String, String> _parseFrontmatter(String content) {
    final result = <String, String>{};
    final lines = content.split('\n');
    var inFrontmatter = false;
    var foundFirst = false;

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed == '---') {
        if (!foundFirst) {
          foundFirst = true;
          inFrontmatter = true;
          continue;
        } else if (inFrontmatter) {
          break;
        }
      }

      if (inFrontmatter) {
        final colonIdx = trimmed.indexOf(':');
        if (colonIdx > 0) {
          final key = trimmed.substring(0, colonIdx).trim();
          var value = trimmed.substring(colonIdx + 1).trim();
          // Strip quotes
          if ((value.startsWith('"') && value.endsWith('"')) ||
              (value.startsWith("'") && value.endsWith("'"))) {
            value = value.substring(1, value.length - 1);
          }
          if (key.isNotEmpty && value.isNotEmpty) {
            result[key] = value;
          }
        }
      }
    }

    return result;
  }

  Future<int> _countFiles(Directory dir) async {
    try {
      return await dir.list().length;
    } catch (_) {
      return 1;
    }
  }

  Future<DateTime?> _lastModified(File file) async {
    try {
      return await file.lastModified();
    } catch (_) {
      return null;
    }
  }

  /// Creates a new skill directory and SKILL.md under the local skills root.
  Future<SkillInfo> registerSkill({
    required String name,
    required String description,
    String category = 'custom',
  }) async {
    final safeName = sanitizeSkillPathSegment(name);
    if (safeName.isEmpty) {
      throw ArgumentError('Skill name is required');
    }
    final safeCategory = sanitizeSkillPathSegment(category);
    final categoryName = safeCategory.isEmpty ? 'custom' : safeCategory;
    final dir = Directory(
      '$_skillsDir${Platform.pathSeparator}$categoryName${Platform.pathSeparator}$safeName',
    );
    await dir.create(recursive: true);

    final skillMd = File('${dir.path}${Platform.pathSeparator}SKILL.md');
    final quotedName = _yamlDoubleQuote(name.trim());
    final quotedDescription = _yamlDoubleQuote(description.trim());
    await skillMd.writeAsString(
      '---\n'
      'name: $quotedName\n'
      'description: $quotedDescription\n'
      '---\n\n'
      '# ${name.trim()}\n\n'
      '${description.trim()}\n',
    );

    return SkillInfo(
      name: name.trim().isEmpty ? safeName : name.trim(),
      description: description.trim(),
      category: categoryName,
      enabled: true,
      lastModified: await _lastModified(skillMd),
      fileCount: await _countFiles(dir),
    );
  }

  /// Persists enabled/disabled state with a `.disabled` marker file.
  Future<void> setSkillEnabled({
    required String name,
    required String category,
    required bool enabled,
  }) async {
    final safeName = sanitizeSkillPathSegment(name);
    final safeCategory = sanitizeSkillPathSegment(category);
    if (safeName.isEmpty || safeCategory.isEmpty) return;
    final marker = File(
      '$_skillsDir${Platform.pathSeparator}$safeCategory${Platform.pathSeparator}$safeName${Platform.pathSeparator}.disabled',
    );
    if (enabled) {
      if (await marker.exists()) {
        await marker.delete();
      }
    } else {
      await marker.parent.create(recursive: true);
      await marker.writeAsString('');
    }
  }
}

String sanitizeSkillPathSegment(String input) {
  final slug = input
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
  return slug;
}

String _yamlDoubleQuote(String value) {
  return '"${value.replaceAll(r'\', r'\\').replaceAll('"', r'\"')}"';
}
