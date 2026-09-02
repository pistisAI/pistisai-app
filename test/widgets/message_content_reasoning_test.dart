import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pistisai/components/message_content.dart';
import 'package:pistisai/models/message.dart';

void main() {
  testWidgets('hides Thinking when reasoning duplicates content',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MessageContent(
            message: Message.assistant(
              content: 'OK\nOK',
              reasoning: 'OK\nOK',
              model: 'hermes-agent',
            ),
          ),
        ),
      ),
    );

    expect(find.text('Thinking'), findsNothing);
    expect(find.text('OK\nOK'), findsOneWidget);
  });

  testWidgets('shows Thinking when reasoning is distinct', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MessageContent(
            message: Message.assistant(
              content: 'Final answer',
              reasoning: 'Step by step plan',
              model: 'hermes-agent',
            ),
          ),
        ),
      ),
    );

    expect(find.text('Thinking'), findsOneWidget);
    expect(find.text('Step by step plan'), findsOneWidget);
    expect(find.text('Final answer'), findsOneWidget);
  });
}
