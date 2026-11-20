import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pistisai/components/message_content.dart';
import 'package:pistisai/models/message.dart';

void main() {
  group('shouldAutoLoadMarkdownImageUrl', () {
    test('allows data: URLs', () {
      expect(
        shouldAutoLoadMarkdownImageUrl(
          'data:image/png;base64,AAAA',
        ),
        isTrue,
      );
    });

    test('allows loopback http(s) URLs', () {
      expect(
        shouldAutoLoadMarkdownImageUrl('http://127.0.0.1:8080/a.png'),
        isTrue,
      );
      expect(
        shouldAutoLoadMarkdownImageUrl('http://localhost/a.png'),
        isTrue,
      );
      expect(
        shouldAutoLoadMarkdownImageUrl('http://[::1]/img'),
        isTrue,
      );
    });

    test('rejects remote http(s) URLs by default', () {
      expect(
        shouldAutoLoadMarkdownImageUrl('https://example.com/track.png?q=1'),
        isFalse,
      );
      expect(
        shouldAutoLoadMarkdownImageUrl('http://evil.example/x.png'),
        isFalse,
      );
    });
  });

  testWidgets('remote markdown images show click-to-load, not Image.network',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MessageContent(
            message: Message.assistant(
              content: '![tracker](https://example.com/pixel.png?q=secret)',
              model: 'hermes-agent',
            ),
          ),
        ),
      ),
    );

    expect(find.text('Load image'), findsOneWidget);
    expect(find.byType(Image), findsNothing);
  });
}
