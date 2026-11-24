import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pistisai/services/popout/popout_manager.dart';
import 'package:pistisai/widgets/navigation/popout_button.dart';

void main() {
  // #858: PopOutManager only records state in memory and never opens a
  // window, so the button must not be offered (AGENTS.md "Controls tell the
  // truth").
  testWidgets('pop-out button is hidden while pop-out windows are not wired',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          appBar: AppBar(
            actions: [
              PopOutButton(
                sectionName: 'usage',
                branchIndex: 5,
                manager: PopOutManager(),
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.byType(IconButton), findsNothing);
    expect(find.byIcon(Icons.open_in_new), findsNothing);
    expect(find.byTooltip('Toggle pop-out window'), findsNothing);
  });
}
