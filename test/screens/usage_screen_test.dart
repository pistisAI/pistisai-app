import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pistisai/l10n/app_localizations.dart';
import 'package:pistisai/screens/usage/usage_screen.dart';

void main() {
  Future<void> pumpUsage(WidgetTester tester, {Locale? locale}) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const UsageScreen(),
      ),
    );
    await tester.pumpAndSettle();
  }

  // #858: the time range selector was never read, the RPM/TPM counters are
  // never written (always 0) and three cards said "Chart placeholder".
  testWidgets('usage screen shows no inert selector, fake rates or charts',
      (tester) async {
    await pumpUsage(tester);

    expect(find.text('Today'), findsNothing);
    expect(find.text('Week'), findsNothing);
    expect(find.text('Month'), findsNothing);
    expect(find.text('Request Rate'), findsNothing);
    expect(find.text('Token Rate'), findsNothing);
    expect(find.text('Chart placeholder'), findsNothing);
    expect(find.byIcon(Icons.open_in_new), findsNothing);

    expect(
      find.text(
          'Request rate, token rate and usage history are not available yet.'),
      findsOneWidget,
    );
    expect(find.text('Active Concurrency'), findsOneWidget);
  });

  testWidgets('not-available notice is translated in French', (tester) async {
    await pumpUsage(tester, locale: const Locale('fr'));

    expect(
      find.text('Le débit de requêtes, le débit de jetons et l\'historique '
          'd\'utilisation ne sont pas encore disponibles.'),
      findsOneWidget,
    );
  });
}
