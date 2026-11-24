import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pistisai/di/locator.dart' as di;
import 'package:pistisai/l10n/app_localizations.dart';
import 'package:pistisai/models/channel.dart';
import 'package:pistisai/screens/channels/channel_detail_screen.dart';
import 'package:pistisai/screens/channels/channels_screen.dart';
import 'package:pistisai/services/channel_service.dart';

class _FakeChannelService implements ChannelService {
  _FakeChannelService(this.channels);

  final List<GatewayChannel> channels;

  @override
  Future<List<GatewayChannel>> listChannels() async => channels;
}

const _channel = GatewayChannel(
  id: 'gw-default',
  name: 'default',
  platform: 'gateway',
  connected: true,
  isCurrent: true,
);

Widget _app(Widget home) => MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: home,
    );

/// Regression tests for #859: channel controls must not report success for
/// work they did not do, and the list must not show invented values.
void main() {
  void register(List<GatewayChannel> channels) {
    if (di.serviceLocator.isRegistered<ChannelService>()) {
      di.serviceLocator.unregister<ChannelService>();
    }
    di.serviceLocator
        .registerSingleton<ChannelService>(_FakeChannelService(channels));
  }

  tearDown(() {
    if (di.serviceLocator.isRegistered<ChannelService>()) {
      di.serviceLocator.unregister<ChannelService>();
    }
  });

  group('ChannelDetailScreen', () {
    testWidgets('controls are labelled not available and report nothing',
        (tester) async {
      register([_channel]);
      await tester.pumpWidget(
        _app(const ChannelDetailScreen(channelId: 'gw-default')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Start Channel'), findsOneWidget);
      expect(find.text('Not available yet'), findsNWidgets(4));
      expect(find.byKey(const Key('channel_controls_not_available')),
          findsOneWidget);

      for (final label in [
        'Start Channel',
        'Stop Channel',
        'Reconnect',
        'View Logs',
      ]) {
        await tester.tap(find.text(label), warnIfMissed: false);
        await tester.pumpAndSettle();
      }

      expect(find.byType(SnackBar), findsNothing,
          reason: 'no control may claim an action was performed');
      expect(find.textContaining('performed'), findsNothing);
    });

    testWidgets('does not invent message count or last activity',
        (tester) async {
      register([_channel]);
      await tester.pumpWidget(
        _app(const ChannelDetailScreen(channelId: 'gw-default')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Messages'), findsNothing);
      expect(find.text('Last Activity'), findsNothing);
      expect(find.text('Connected'), findsOneWidget);
      expect(find.text('Active gateway profile (current)'), findsOneWidget);
    });
  });

  group('ChannelsScreen', () {
    testWidgets('shows the empty state when the gateway lists nothing',
        (tester) async {
      register(const []);
      await tester.pumpWidget(_app(const ChannelsScreen()));
      await tester.pumpAndSettle();

      expect(find.text('No Channels'), findsOneWidget);
    });

    testWidgets('shows reported status, not invented counts', (tester) async {
      register([_channel]);
      await tester.pumpWidget(_app(const ChannelsScreen()));
      await tester.pumpAndSettle();

      expect(find.text('default'), findsOneWidget);
      expect(find.text('Connected'), findsOneWidget);
      expect(find.text('0 messages'), findsNothing);
      expect(find.text('Read'), findsNothing);
      expect(find.text('Never'), findsNothing);
    });
  });
}
