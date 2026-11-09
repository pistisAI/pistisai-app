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

String skillFolderSlug(String input) {
  final slug = input
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
  return slug.isEmpty ? 'skill' : slug;
}

/// Reads the local Hermes skills directory and parses skill metadata.
///
/// Skills live at `~/.hermes/skills/<category>/<name>/SKILL.md`.
/// Each SKILL.md has YAML frontmatter with name, description, tags.
class SkillService {
  final String _skillsDir;

  SkillService({String? skillsDir})
      : _skillsDir = skillsDir ?? defaultSkillsDir();

  String get skillsDirectory => _skillsDir;

  static String defaultSkillsDir() {
    try {
      // On Windows, Hermes uses %LOCALAPPDATA%\hermes\skills (no leading dot).
      // On macOS/Linux it is ~/.hermes/skills.
      if (Platform.isWindows) {
        final appData = Platform.environment['LOCALAPPDATA'] ??
            Platform.environment['USERPROFILE'] ??
            '.';
        return '$appData\\hermes\\skills';
      }
      final home = Platform.environment['HOME'] ?? '.';
      return '$home/.hermes/skills';
    } catch (_) {
      return '.hermes/skills';
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

            skills.add(SkillInfo(
              name: metadata['name'] ?? skillName,
              description: metadata['description'] ?? '',
              category: categoryName,
              enabled: true,
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

  /// Writes a new `SKILL.md` under the local Hermes skills directory.
  Future<SkillInfo> registerSkill({
    required String name,
    required String description,
    String category = 'custom',
  }) async {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      throw ArgumentError('Skill name is required');
    }

    final trimmedDescription = description.trim();
    if (trimmedDescription.isEmpty) {
      throw ArgumentError('Skill description is required');
    }

    final categorySlug = skillFolderSlug(category);
    final nameSlug = skillFolderSlug(trimmedName);
    final dir = Directory('$_skillsDir/$categorySlug/$nameSlug');
    await dir.create(recursive: true);

    final skillMd = File('${dir.path}/SKILL.md');
    if (await skillMd.exists()) {
      throw StateError(
        'A skill named "${trimmedDescription.isEmpty ? trimmedName : trimmedName}" '
        'already exists at ${skillMd.path}. '
        'Delete or rename the existing skill before registering again.',
      );
    }

    final yamlName = _yamlQuote(trimmedName);
    final yamlDescription = _yamlQuote(trimmedDescription);
    await skillMd.writeAsString(
      '---\n'
      'name: $yamlName\n'
      'description: $yamlDescription\n'
      '---\n\n'
      '# $trimmedName\n\n'
      '$trimmedDescription\n',
    );

    return SkillInfo(
      name: trimmedName,
      description: trimmedDescription,
      category: categorySlug,
      enabled: true,
      lastModified: await _lastModified(skillMd),
      fileCount: await _countFiles(dir),
    );
  }

  String _yamlQuote(String value) {
    // Escape backslashes and double-quotes, then strip characters that would
    // break YAML inline double-quoted scalars (newlines, tabs, NUL).
    final safe = value
        .replaceAll(r'\', r'\\')
        .replaceAll('"', r'\"')
        .replaceAll('\n', ' ')
        .replaceAll('\r', '')
        .replaceAll('\t', ' ');
    return '"$safe"';
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
}
