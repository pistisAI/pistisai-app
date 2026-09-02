import 'dart:io';
import 'package:flutter/foundation.dart';

/// Installation status of the OpenClaw skill.
enum OpenClawSkillStatus {
  /// Skill is not installed.
  notInstalled,

  /// Skill is installed and ready.
  installed,

  /// Installation is in progress.
  installing,

  /// Installation failed.
  error,
}

/// Manages detection, installation, and status of the OpenClaw personality skill.
///
/// The skill package lives at `services/openclaw-skills/pistisai/` in the
/// Pistisai app repository. It is installed to `~/.openclaw/skills/pistisai/`
/// so that the OpenClaw gateway can load it at runtime.
class OpenClawSkillInstallService extends ChangeNotifier {
  OpenClawSkillStatus _status = OpenClawSkillStatus.notInstalled;
  String? _errorMessage;
  String? _installedVersion;

  OpenClawSkillStatus get status => _status;
  String? get errorMessage => _errorMessage;
  String? get installedVersion => _installedVersion;
  bool get isInstalled => _status == OpenClawSkillStatus.installed;

  /// Returns the target installation directory for the OpenClaw skill.
  String get _targetDir {
    try {
      final home = Platform.environment['HOME'] ??
          Platform.environment['USERPROFILE'] ??
          '/tmp';
      return '$home/.openclaw/skills/pistisai';
    } catch (_) {
      return '/tmp/.openclaw/skills/pistisai';
    }
  }

  /// Returns the source directory within the Pistisai app repository.
  ///
  /// On a running desktop app this is resolved relative to the executable;
  /// we check several common layouts.
  String get _sourceDir {
    try {
      // When running from the repo checkout
      final candidates = [
        'services/openclaw-skills/pistisai',
        '../services/openclaw-skills/pistisai',
        '../../services/openclaw-skills/pistisai',
      ];

      for (final candidate in candidates) {
        final dir = Directory(candidate);
        if (dir.existsSync()) {
          return dir.absolute.path;
        }
      }

      // Fallback: check relative to the executable
      final script = Platform.script.toFilePath();
      final scriptDir = Directory(script).parent;
      final relative = '${scriptDir.path}/services/openclaw-skills/pistisai';
      if (Directory(relative).existsSync()) {
        return relative;
      }

      return '';
    } catch (_) {
      return '';
    }
  }

  /// Check whether the OpenClaw skill is currently installed.
  Future<void> checkStatus() async {
    final target = Directory(_targetDir);
    final packageJson = File('$target/package.json');

    if (target.existsSync() && packageJson.existsSync()) {
      try {
        final content = await packageJson.readAsString();
        final versionMatch = RegExp(r'"version"\s*:\s*"([^"]+)"').firstMatch(content);
        _installedVersion = versionMatch?.group(1) ?? 'unknown';
        _status = OpenClawSkillStatus.installed;
        _errorMessage = null;
      } catch (e) {
        _status = OpenClawSkillStatus.installed;
        _installedVersion = 'unknown';
        _errorMessage = null;
      }
    } else {
      _status = OpenClawSkillStatus.notInstalled;
      _installedVersion = null;
      _errorMessage = null;
    }

    notifyListeners();
  }

  /// Install the OpenClaw skill by copying the package to the target directory.
  ///
  /// Returns `true` on success, `false` on failure (check [errorMessage]).
  Future<bool> install() async {
    _status = OpenClawSkillStatus.installing;
    _errorMessage = null;
    notifyListeners();

    try {
      final source = _sourceDir;
      if (source.isEmpty) {
        _status = OpenClawSkillStatus.error;
        _errorMessage =
            'Could not locate the OpenClaw skill package. '
            'The Pistisai app repository may not be present on this system.';
        notifyListeners();
        return false;
      }

      final sourceDir = Directory(source);
      if (!sourceDir.existsSync()) {
        _status = OpenClawSkillStatus.error;
        _errorMessage = 'Source skill package not found at: $source';
        notifyListeners();
        return false;
      }

      // Create target directory
      final target = Directory(_targetDir);
      if (target.existsSync()) {
        // Remove existing installation first
        await target.delete(recursive: true);
      }
      await target.create(recursive: true);

      // Copy all files recursively
      await _copyDirectory(sourceDir, target);

      // Verify installation
      final packageJson = File('${target.path}/package.json');
      if (!packageJson.existsSync()) {
        _status = OpenClawSkillStatus.error;
        _errorMessage = 'Installation completed but package.json is missing.';
        notifyListeners();
        return false;
      }

      final content = await packageJson.readAsString();
      final versionMatch = RegExp(r'"version"\s*:\s*"([^"]+)"').firstMatch(content);
      _installedVersion = versionMatch?.group(1) ?? 'installed';
      _status = OpenClawSkillStatus.installed;
      notifyListeners();
      return true;
    } catch (e) {
      _status = OpenClawSkillStatus.error;
      _errorMessage = 'Installation failed: $e';
      notifyListeners();
      return false;
    }
  }

  /// Recursively copy a directory.
  Future<void> _copyDirectory(Directory source, Directory target) async {
    await for (final entity in source.list()) {
      final destPath = '${target.path}/${entity.uri.pathSegments.last}';

      if (entity is Directory) {
        // Skip node_modules — they should be installed fresh
        if (entity.uri.pathSegments.last == 'node_modules') continue;
        await Directory(destPath).create(recursive: true);
        await _copyDirectory(entity, Directory(destPath));
      } else if (entity is File) {
        await entity.copy(destPath);
      }
    }
  }

  /// Returns manual installation instructions for the user.
  static String get manualInstallInstructions => '''
## Manual Installation

If the one-click install does not work, you can install the OpenClaw skill manually:

### From the Pistisai repository:

```bash
# Clone or navigate to the Pistisai app repository
cd pistisai-app

# Create the target directory
mkdir -p ~/.openclaw/skills/pistisai

# Copy the skill package
cp -r services/openclaw-skills/pistisai/* ~/.openclaw/skills/pistisai/

# Install dependencies
cd ~/.openclaw/skills/pistisai
npm install
```

### Verify installation:

```bash
ls -la ~/.openclaw/skills/pistisai/
cat ~/.openclaw/skills/pistisai/package.json
```

The skill should now be available to the OpenClaw gateway.
''';
}
