import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pistisai/models/user_model.dart';
import 'package:pistisai/screens/login_screen.dart';
import 'package:pistisai/services/auth_service.dart';
import 'package:pistisai/services/platform_detection_service.dart';
import 'package:pistisai/services/theme_provider.dart';
import 'package:provider/provider.dart';

import '../helpers/mock_services.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pumpLogin(WidgetTester tester, AuthService auth) async {
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<ThemeProvider>(
            create: (_) => ThemeProvider(skipLoad: true),
          ),
          ChangeNotifierProvider<PlatformDetectionService>(
            create: (_) => PlatformDetectionService(),
          ),
          ChangeNotifierProvider<AuthService>.value(value: auth),
        ],
        child: const MaterialApp(home: LoginScreen()),
      ),
    );
    await tester.pump();
  }

  testWidgets('greets a signed-in user by display name', (tester) async {
    final auth = createMockAuthService(authenticated: true);

    await pumpLogin(tester, auth);

    expect(find.text('Hey Test User!'), findsOneWidget);
    expect(find.text('Hey Christopher!'), findsNothing);
    expect(find.text('Bypass to Test User (Debug)'), findsOneWidget);
  });

  testWidgets('uses a nameless greeting when nobody is signed in',
      (tester) async {
    await pumpLogin(tester, createMockAuthService());

    expect(find.text('Hey!'), findsOneWidget);
    expect(find.textContaining('Christopher'), findsNothing);
  });

  testWidgets('uses a nameless greeting when the display name is blank',
      (tester) async {
    final auth = _UserAuth(
      UserModel(
        id: 'blank',
        email: '',
        name: '   ',
        nickname: ' ',
        createdAt: DateTime.utc(2024),
        updatedAt: DateTime.utc(2024),
      ),
    );

    await pumpLogin(tester, auth);

    expect(find.text('Hey!'), findsOneWidget);
  });

  testWidgets('falls through displayName to nickname when name is absent',
      (tester) async {
    final auth = _UserAuth(
      UserModel(
        id: 'nick',
        email: 'ada@example.com',
        nickname: 'Ada',
        createdAt: DateTime.utc(2024),
        updatedAt: DateTime.utc(2024),
      ),
    );

    await pumpLogin(tester, auth);

    expect(find.text('Hey Ada!'), findsOneWidget);
  });
}

class _UserAuth extends MockAuthService {
  _UserAuth(this._user);

  final UserModel? _user;

  @override
  UserModel? get currentUser => _user;
}
