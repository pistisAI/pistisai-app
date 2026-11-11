import 'package:flutter_test/flutter_test.dart';
import 'package:pistisai/screens/onboarding/steps/connection_test_step.dart';

void main() {
  group('connectionTestView', () {
    test('shows success only for a test that passed', () {
      expect(
        connectionTestView(isLoading: false, errorMessage: null, verified: true),
        ConnectionTestView.verified,
      );
    });

    test('no error and no passed test is "not tested", never success', () {
      expect(
        connectionTestView(
            isLoading: false, errorMessage: null, verified: false),
        ConnectionTestView.notTested,
      );
    });

    test('an error wins over an earlier success', () {
      expect(
        connectionTestView(
            isLoading: false, errorMessage: 'unreachable', verified: true),
        ConnectionTestView.failed,
      );
    });

    test('a running test shows progress', () {
      expect(
        connectionTestView(isLoading: true, errorMessage: 'old', verified: true),
        ConnectionTestView.testing,
      );
    });
  });
}
