import 'package:flutter_test/flutter_test.dart';
import 'package:pistisai/auth/auth_provider.dart';
import 'package:pistisai/auth/providers/supabase_auth_provider.dart';

/// Unit coverage for the paths of [SupabaseAuthProvider] that do not require a
/// live `Supabase.initialize()` (the OAuth/session paths are exercised against
/// the real SDK at runtime). Focuses on the provider/interface contract and the
/// developer bypass used by the login screen in debug builds.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SupabaseAuthProvider', () {
    test('implements the AuthProvider interface', () {
      final provider = SupabaseAuthProvider();
      expect(provider, isA<AuthProvider>());
      provider.dispose();
    });

    test('starts unauthenticated with a seeded false auth state', () async {
      final provider = SupabaseAuthProvider();
      expect(provider.currentUser, isNull);
      await expectLater(provider.authStateChanges.first, completion(isFalse));
      provider.dispose();
    });

    test('loginMockDeveloper authenticates with the dev user and emits true',
        () async {
      final provider = SupabaseAuthProvider();
      final emitted = <bool>[];
      final sub = provider.authStateChanges.listen(emitted.add);

      await provider.loginMockDeveloper();
      // Allow the BehaviorSubject to deliver the queued events.
      await Future<void>.delayed(Duration.zero);

      expect(provider.currentUser, isNotNull);
      expect(provider.currentUser!.email, 'dev@pistisai.app');
      expect(provider.currentUser!.displayName, 'Christopher (Dev)');
      expect(emitted.last, isTrue);

      await sub.cancel();
      provider.dispose();
    });
  });
}
