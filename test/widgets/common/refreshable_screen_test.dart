import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pistisai/widgets/common/refreshable_screen.dart';

Widget _app(String? error) => MaterialApp(
      home: Scaffold(
        body: RefreshableScreen(
          onRefresh: () async {},
          errorMessage: error,
          child: ListView(children: const [Text('row')]),
        ),
      ),
    );

void main() {
  testWidgets('a load error after the first build shows the banner',
      (tester) async {
    await tester.pumpWidget(_app(null));
    await tester.pumpWidget(_app('could not load'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('could not load'), findsOneWidget);
    expect(find.text('row'), findsOneWidget);
  });

  testWidgets('an error passed on the first build is shown', (tester) async {
    await tester.pumpWidget(_app('could not load'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('could not load'), findsOneWidget);
  });
}
