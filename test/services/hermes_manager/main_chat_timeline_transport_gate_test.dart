import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('main chat cockpit transport review gate', () {
    test('sync gate rules stay explicit in the review document', () {
      final gateDoc = File(
        'docs/archive/plans/2026-05-09-main-chat-cockpit-transport-review-gate.md',
      ).readAsStringSync();

      expect(gateDoc, contains('No unauthenticated listener.'));
      expect(gateDoc, contains('No all-interface bind by default.'));
      expect(gateDoc, contains('No client-selected target IP or route authority.'));
      expect(gateDoc, contains('No unpaired-device writes.'));
      expect(gateDoc, contains('No user-JWT-as-device-auth.'));
    });
  });
}
