// Release-notes images load only when the user taps them (#1003).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pistisai/l10n/app_localizations.dart';
import 'package:pistisai/screens/config/config_screen.dart';

void main() {
  Future<void> pump(WidgetTester tester, String data) {
    return tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: ChangelogMarkdown(data: data)),
      ),
    );
  }

  testWidgets('release-notes image is not fetched until tapped',
      (tester) async {
    await pump(tester, 'Notes\n\n![diagram](https://img.example.com/a.png)');
    await tester.pump();

    expect(find.byType(Image), findsNothing);
    expect(find.text('Load image: diagram'), findsOneWidget);

    await tester.tap(find.text('Load image: diagram'));
    await tester.pump();

    final image = tester.widget<Image>(find.byType(Image));
    expect(image.image, isA<NetworkImage>());
    expect((image.image as NetworkImage).url, 'https://img.example.com/a.png');
  });

  testWidgets('non-http image links cannot be loaded', (tester) async {
    await pump(tester, '![x](file:///etc/passwd)');
    await tester.pump();

    expect(find.byType(Image), findsNothing);
    final button = tester.widget<TextButton>(find.byType(TextButton));
    expect(button.onPressed, isNull);
  });
}
