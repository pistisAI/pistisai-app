import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await SharedPreferences.getInstance();
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SharedPreferences.getInstance();
  });

  testWidgets('Test shared prefs with setUp', (tester) async {
    final prefs = await SharedPreferences.getInstance();
    await Future.wait([
      prefs.setString('k1', 'v1'),
      prefs.setInt('k2', 1),
    ]);
  });
}
