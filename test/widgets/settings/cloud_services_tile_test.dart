import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pistisai/brand/brand.dart';
import 'package:pistisai/l10n/app_localizations.dart';
import 'package:pistisai/services/cloud_connector_service.dart';
import 'package:pistisai/services/settings_preference_service.dart';
import 'package:pistisai/widgets/settings/cloud_services_tile.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeConnector implements CloudConnectorService {
  _FakeConnector({this.registers = true});

  final bool registers;
  int registerCalls = 0;
  int stopCalls = 0;

  @override
  Future<bool> registerAndStart({
    CloudRuntimeLocation runtimeLocation = CloudRuntimeLocation.local,
  }) async {
    registerCalls++;
    return registers;
  }

  @override
  void stop() => stopCalls++;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      super.noSuchMethod(invocation);
}

Future<void> _pump(WidgetTester tester, Widget child) async {
  await tester.pumpWidget(MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: SingleChildScrollView(child: child)),
  ));
  await tester.pumpAndSettle();
}

SwitchListTile _tile(WidgetTester tester) =>
    tester.widget<SwitchListTile>(find.byType(SwitchListTile));

Future<bool> _stored() => SettingsPreferenceService().isCloudServicesEnabled();

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('cloud services switch is off by default', (tester) async {
    await _pump(tester, CloudServicesTile(connector: _FakeConnector()));

    expect(find.text('Cloud services'), findsOneWidget);
    expect(_tile(tester).value, isFalse);
    expect(find.textContaining('Off by default'), findsOneWidget);
    expect(await _stored(), isFalse);
  });

  testWidgets('turning on shows the consent dialog; cancel keeps it off',
      (tester) async {
    final connector = _FakeConnector();
    await _pump(tester, CloudServicesTile(connector: connector));

    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();

    expect(find.byType(CloudServicesConsentDialog), findsOneWidget);
    expect(await _stored(), isFalse, reason: 'nothing saved before confirm');

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.byType(CloudServicesConsentDialog), findsNothing);
    expect(_tile(tester).value, isFalse);
    expect(await _stored(), isFalse);
    expect(connector.registerCalls, 0);
  });

  testWidgets('confirming persists the opt-in and starts registration',
      (tester) async {
    final connector = _FakeConnector();
    await _pump(tester, CloudServicesTile(connector: connector));

    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Turn on'));
    await tester.pumpAndSettle();

    expect(_tile(tester).value, isTrue);
    expect(await _stored(), isTrue);
    expect(connector.registerCalls, 1);
    expect(find.textContaining('This device is registered'), findsOneWidget);
  });

  testWidgets('a registration that does not complete is reported as such',
      (tester) async {
    await _pump(
        tester, CloudServicesTile(connector: _FakeConnector(registers: false)));

    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Turn on'));
    await tester.pumpAndSettle();

    expect(await _stored(), isTrue);
    expect(find.textContaining('has not completed'), findsOneWidget);
  });

  testWidgets('turning off persists without a dialog and keeps server data',
      (tester) async {
    SharedPreferences.setMockInitialValues(
        {'settings_cloud_services_enabled': true});
    final connector = _FakeConnector();
    await _pump(tester, CloudServicesTile(connector: connector));
    expect(_tile(tester).value, isTrue);

    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();

    expect(find.byType(CloudServicesConsentDialog), findsNothing);
    expect(_tile(tester).value, isFalse);
    expect(await _stored(), isFalse);
    expect(connector.stopCalls, 1);
    expect(find.textContaining('does not delete it'), findsOneWidget);
  });

  testWidgets('the dialog names the destination and the three data flows',
      (tester) async {
    await _pump(tester, const CloudServicesConsentDialog(isWeb: false));

    final product = Brand.current.productName;
    expect(find.textContaining('the $product cloud service'), findsOneWidget);
    expect(find.textContaining('Device registration and a heartbeat'),
        findsOneWidget);
    expect(find.textContaining('Brain sync'), findsOneWidget);
    expect(find.textContaining('Chat history, while you are signed in'),
        findsOneWidget);
    expect(find.textContaining('does not delete'), findsOneWidget);
    expect(find.textContaining('In the web app'), findsNothing);
  });

  testWidgets('the web dialog says web chat history is stored regardless',
      (tester) async {
    await _pump(tester, const CloudServicesConsentDialog(isWeb: true));

    expect(find.textContaining('In the web app'), findsOneWidget);
  });
}
