import 'package:flutter_test/flutter_test.dart';
import 'package:pistisai/services/hub/client_connectivity.dart';

void main() {
  group('resolveChatTransport', () {
    test('primary hub keeps the local Hermes gateway', () {
      final decision = resolveChatTransport(
        role: ClientInstallRole.primaryHub,
        configuredUrl: null,
        hubUrl: null,
      );

      expect(decision.allowed, isTrue);
      expect(decision.viaHub, isFalse);
      expect(decision.baseUrl, 'http://127.0.0.1:8642');
    });

    test('web refuses loopback Hermes and accepts the hub port', () {
      final refused = resolveChatTransport(
        role: ClientInstallRole.web,
        configuredUrl: 'http://127.0.0.1:8642',
        hubUrl: null,
      );
      expect(refused.allowed, isFalse);
      expect(refused.refusal, directHermesRefusal);

      final joined = resolveChatTransport(
        role: ClientInstallRole.web,
        configuredUrl: 'http://pc.tailnet.ts.net:8642',
        hubUrl: null,
      );
      expect(joined.allowed, isTrue);
      expect(joined.viaHub, isTrue);
      expect(joined.baseUrl, 'http://pc.tailnet.ts.net:1337');

      final explicit = resolveChatTransport(
        role: ClientInstallRole.mobile,
        configuredUrl: null,
        hubUrl: 'http://100.64.1.20:1337/api/pistisai/hub',
      );
      expect(explicit.baseUrl, 'http://100.64.1.20:1337');
      expect(explicit.viaHub, isTrue);
    });

    test('a remote gateway URL makes a desktop a secondary hub client', () {
      final role = roleForConfiguredUrl(
        detected: ClientInstallRole.primaryHub,
        url: 'http://100.64.1.20:8642',
      );
      expect(role, ClientInstallRole.secondaryDesktop);

      final decision = resolveChatTransport(
        role: role,
        configuredUrl: 'http://100.64.1.20:8642',
        hubUrl: null,
      );
      expect(decision.baseUrl, 'http://100.64.1.20:1337');
      expect(decision.viaHub, isTrue);
    });
  });

  group('resolveClientInstallRole', () {
    test('stored role wins, otherwise web and mobile are not the hub', () {
      expect(
        resolveClientInstallRole(
          isWeb: true,
          isMobile: false,
          storedRole: 'primary_hub',
          hubUrl: null,
          hermesUrl: null,
        ),
        ClientInstallRole.primaryHub,
      );
      expect(
        resolveClientInstallRole(
          isWeb: true,
          isMobile: false,
          storedRole: null,
          hubUrl: null,
          hermesUrl: null,
        ),
        ClientInstallRole.web,
      );
      expect(
        resolveClientInstallRole(
          isWeb: false,
          isMobile: true,
          storedRole: null,
          hubUrl: null,
          hermesUrl: null,
        ),
        ClientInstallRole.mobile,
      );
      expect(
        resolveClientInstallRole(
          isWeb: false,
          isMobile: false,
          storedRole: null,
          hubUrl: null,
          hermesUrl: 'http://127.0.0.1:8642',
        ),
        ClientInstallRole.primaryHub,
      );
    });
  });
}
