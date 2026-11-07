import 'package:flutter_test/flutter_test.dart';
import 'package:pistisai/auth/access_token_store.dart';
import 'package:pistisai/auth/cloudflare_access_config.dart';
import 'package:pistisai/auth/providers/cloudflare_access_auth_provider.dart';
import 'package:pistisai/services/enhanced_user_tier_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('login URL targets the api.pistisai.app Access app', () {
    final uri = CloudflareAccessConfig.loginUri();
    expect(uri.host, 'pistisai.cloudflareaccess.com');
    expect(uri.path, contains(CloudflareAccessConfig.audience));
    expect(CloudflareAccessConfig.tunnelHost, 'api.pistisai.app');
    expect(CloudflareAccessConfig.appHost, 'app.pistisai.app');
  });

  test(
      'free tier sign-in stores the Access token and does not call the network itself',
      () async {
    final store = MemoryAccessTokenStore();
    Uri? opened;
    final provider = CloudflareAccessAuthProvider(
      store: store,
      currentTier: () => UserTier.free,
      emailFromToken: (_) => 'ada@example.com',
      loginFlow: (uri) async {
        opened = uri;
        return 'header.payload.sig';
      },
    );

    await provider.initialize();
    expect(provider.currentUser, isNull);
    expect(provider.accessRequired, isTrue);

    await provider.login();

    expect(opened, isNotNull);
    expect(provider.customerNetwork, isFalse);
    expect(await provider.getAccessToken(), 'header.payload.sig');
    expect(provider.currentUser?.email, 'ada@example.com');
    expect(await store.read(), 'header.payload.sig');
  });

  test('business tier skips Access and does not open a login', () async {
    var opened = false;
    final provider = CloudflareAccessAuthProvider(
      store: MemoryAccessTokenStore(),
      currentTier: () => UserTier.business,
      loginFlow: (_) async {
        opened = true;
        return 'should-not-be-used';
      },
    );

    await provider.login();

    expect(opened, isFalse);
    expect(provider.customerNetwork, isTrue);
    expect(provider.accessRequired, isFalse);
    expect(await provider.getAccessToken(), isNull);
    expect(
      tunnelAccessHeaders(
        customerNetwork: true,
        accessToken: 'ignored',
      ),
      isEmpty,
    );
  });

  test('enterprise tier skips Access', () async {
    final provider = CloudflareAccessAuthProvider(
      store: MemoryAccessTokenStore(),
      currentTier: () => UserTier.enterprise,
      loginFlow: (_) async => 'nope',
    );

    await provider.initialize();

    expect(provider.customerNetwork, isTrue);
    expect(await provider.getAccessToken(), isNull);
  });

  test('callback accepts a CF_Authorization query token', () async {
    final provider = CloudflareAccessAuthProvider(
      store: MemoryAccessTokenStore(),
      currentTier: () => UserTier.free,
      emailFromToken: (_) => 'ada@example.com',
    );

    final ok = await provider.handleCallback(
      url: 'pistisai://callback?CF_Authorization=jwt-value',
    );

    expect(ok, isTrue);
    expect(await provider.getAccessToken(), 'jwt-value');
  });

  test('free tier headers carry the Access token', () {
    final headers = tunnelAccessHeaders(
      customerNetwork: false,
      accessToken: 'jwt-value',
    );
    expect(headers['cf-access-token'], 'jwt-value');
    expect(headers['Cf-Access-Jwt-Assertion'], 'jwt-value');
  });
}
