import 'package:flutter_test/flutter_test.dart';
import 'package:pistisai/screens/onboarding/steps/hermes_url_step.dart';

void main() {
  test('hermesRemoteApiKeyOnServerCommand reads API_SERVER_KEY from env file',
      () {
    expect(
      hermesRemoteApiKeyOnServerCommand(),
      "grep '^API_SERVER_KEY=' ~/.hermes/.env | cut -d= -f2-",
    );
  });
}
