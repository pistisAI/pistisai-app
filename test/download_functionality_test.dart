import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';

/// Test suite for download functionality.
///
/// The GitHub API integration tests hit the live release API and are gated
/// behind the `PISTISAI_NETWORK_E2E` environment variable, matching the
/// repo-wide opt-in pattern used by `PISTISAI_HARDWARE_E2E` /
/// `PISTISAI_NATIVE_E2E`. They are skipped by default so CI stays hermetic,
/// and perform real assertions when explicitly enabled.
void main() {
  group('Download Functionality Tests', () {
    const String repoOwner = 'imrightguy';
    const String repoName = 'Pistisai';
    const String baseApiUrl = 'https://api.github.com/repos';
    final bool networkEnabled =
        Platform.environment['PISTISAI_NETWORK_E2E'] == '1';

    test('GitHub API - Latest Release Accessible', () async {
      final url = '$baseApiUrl/$repoOwner/$repoName/releases/latest';
      final response = await Dio().get(url);

      expect(response.statusCode, 200,
          reason: 'GitHub API should be accessible');

      final data = response.data;
      expect(data['tag_name'], isNotNull,
          reason: 'Release should have a tag name');
      expect(data['assets'], isNotEmpty,
          reason: 'Release should have assets');
    }, skip: !networkEnabled);

    test('GitHub API - Release Assets Have Valid URLs', () async {
      final url = '$baseApiUrl/$repoOwner/$repoName/releases/latest';
      final response = await Dio().get(url);

      expect(response.statusCode, 200);

      final data = response.data;
      final List<dynamic> assets = data['assets'];

      for (final asset in assets) {
        final String downloadUrl = asset['browser_download_url'];
        expect(downloadUrl, startsWith('https://github.com/'));
        expect(downloadUrl, contains('/releases/download/'));

        // Test that the download URL is accessible (returns 200 or 302)
        final downloadResponse = await Dio().head(downloadUrl);
        expect([200, 302].contains(downloadResponse.statusCode), true,
            reason: 'Download URL should be accessible: $downloadUrl');
      }
    }, skip: !networkEnabled);

    test('Expected Asset Files Present', () async {
      final url = '$baseApiUrl/$repoOwner/$repoName/releases/latest';
      final response = await Dio().get(url);

      expect(response.statusCode, 200);

      final data = response.data;
      final List<dynamic> assets = data['assets'];
      final assetNames = assets.map((asset) => asset['name'] as String).toList();

      // Check for expected files
      final hasPortableZip = assetNames.any((name) => name.contains('portable.zip'));
      final hasWindowsInstaller = assetNames.any((name) => name.contains('Setup.exe'));

      expect(hasPortableZip, true, reason: 'Should have portable ZIP file');
      expect(hasWindowsInstaller, true, reason: 'Should have Windows installer');
    }, skip: !networkEnabled);

    test('Asset Sizes Are Reasonable', () async {
      final url = '$baseApiUrl/$repoOwner/$repoName/releases/latest';
      final response = await Dio().get(url);

      expect(response.statusCode, 200);

      final data = response.data;
      final List<dynamic> assets = data['assets'];

      for (final asset in assets) {
        final int size = asset['size'];
        final String name = asset['name'];

        if (name.contains('.zip') || name.contains('.exe')) {
          // Desktop applications should be at least 1MB and less than 100MB
          expect(size, greaterThan(1024 * 1024),
              reason: '$name should be at least 1MB');
          expect(size, lessThan(100 * 1024 * 1024),
              reason: '$name should be less than 100MB');
        }
      }
    }, skip: !networkEnabled);

    test('Release Information Complete', () async {
      final url = '$baseApiUrl/$repoOwner/$repoName/releases/latest';
      final response = await Dio().get(url);

      expect(response.statusCode, 200);

      final data = response.data;

      // Check required fields
      expect(data['tag_name'], isNotNull);
      expect(data['name'], isNotNull);
      expect(data['published_at'], isNotNull);
      expect(data['assets'], isNotEmpty);

      // Check that tag name follows version format
      final String tagName = data['tag_name'];
      expect(tagName, matches(r'^v\d+\.\d+\.\d+'),
          reason: 'Tag should follow version format');
    }, skip: !networkEnabled);
  });

  group('Download URL Construction Tests', () {
    test('Construct Valid Download URLs', () {
      const version = 'v3.14.45';
      const repoOwner = 'imrightguy';
      const repoName = 'Pistisai';

      final portableUrl =
          'https://github.com/$repoOwner/$repoName/releases/download/$version/pistisai-${version.substring(1)}-portable.zip';
      final installerUrl =
          'https://github.com/$repoOwner/$repoName/releases/download/$version/Pistisai-Windows-${version.substring(1)}-Setup.exe';

      expect(portableUrl, startsWith('https://github.com/'));
      expect(installerUrl, startsWith('https://github.com/'));
      expect(portableUrl, contains('/releases/download/'));
      expect(installerUrl, contains('/releases/download/'));
    });
  });
}