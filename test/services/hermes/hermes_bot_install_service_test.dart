import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pistisai/services/hermes/hermes_bot_install_service.dart';

void main() {
  group('HermesBotInstallService', () {
    test('can be instantiated', () {
      final service = HermesBotInstallService();
      expect(service, isNotNull);
    });

    test('returns a report', () async {
      final service = HermesBotInstallService(
        loadAsset: (path) => Future.value(ByteData(0)),
        readHermesHome: () => '',
      );
      final report = await service.install();
      expect(report, isNotNull);
      expect(report.steps.length, equals(4));
    });
  });
}
