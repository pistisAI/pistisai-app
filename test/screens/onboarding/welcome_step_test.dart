import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pistisai/screens/onboarding/steps/welcome_step.dart';

void main() {
  testWidgets('WelcomeStep shows full info message in compact wizard viewport',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            key: Key('welcome_viewport'),
            height: 520,
            width: 1280,
            child: WelcomeStep(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('We\'ll set up your local AI'), findsOneWidget);

    final infoTextFinder = find.textContaining('We\'ll set up your local AI');
    final infoBoxRect = tester.getRect(infoTextFinder);
    final viewportBottom =
        tester.getBottomLeft(find.byKey(const Key('welcome_viewport'))).dy;

    expect(
      infoBoxRect.bottom,
      lessThanOrEqualTo(viewportBottom + 1),
      reason: 'Info message should fit within the welcome step viewport',
    );
  });
}
