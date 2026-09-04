import 'package:flutter_test/flutter_test.dart';
import 'package:pistisai/screens/onboarding/steps/hermes_url_step.dart';

void main() {
  test('hermesRemoteApiKeySshCommand uses Tailscale host from URL', () {
    expect(
      hermesRemoteApiKeySshCommand('100.105.103.104'),
      "ssh YOUR_USER@100.105.103.104 \"grep '^API_SERVER_KEY=' ~/.hermes/.env | cut -d= -f2-\"",
    );
  });

  test('hermesRemoteApiKeyOnServerCommand reads API_SERVER_KEY from env file',
      () {
    expect(
      hermesRemoteApiKeyOnServerCommand(),
      "grep '^API_SERVER_KEY=' ~/.hermes/.env | cut -d= -f2-",
    );
  });

  test('hermesHostFromUrl extracts host from Hermes URL', () {
    expect(
      hermesHostFromUrl('http://100.105.103.104:8642'),
      '100.105.103.104',
    );
    expect(hermesHostFromUrl('not-a-url'), isNull);
  });
}
