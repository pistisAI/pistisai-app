import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pistisai/features/avatar/avatar_widget.dart';
import 'package:pistisai/features/avatar/emoji_blending_avatar.dart';
import 'package:pistisai/services/avatar/avatar_appearance.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('AvatarAppearance', () {
    test('defaults when nothing is saved', () async {
      SharedPreferences.setMockInitialValues({});
      final a = AvatarAppearance.fromPreferences(
          await SharedPreferences.getInstance());
      expect(a.sizeMultiplier, 1.0);
      expect(a.glowEnabled, isTrue);
      expect(a.colorOverride, isNull);
    });

    test('reads size, glow and colour as the settings screen saves them',
        () async {
      SharedPreferences.setMockInitialValues({
        'avatar_size': 'large',
        'avatar_glow_enabled': false,
        'avatar_color_override': '#ff8800',
      });
      final a = AvatarAppearance.fromPreferences(
          await SharedPreferences.getInstance());
      expect(a.sizeMultiplier, 1.3);
      expect(a.glowEnabled, isFalse);
      expect(a.colorOverride, const Color(0xFFFF8800));
    });

    test('ignores an invalid colour', () {
      expect(AvatarAppearance.parseColor('not-a-colour'), isNull);
      expect(AvatarAppearance.parseColor('#12'), isNull);
    });

    test('reloadAvatarAppearance publishes the saved values', () async {
      SharedPreferences.setMockInitialValues({'avatar_size': 'small'});
      await reloadAvatarAppearance();
      expect(avatarAppearance.value.sizeMultiplier, 0.8);
    });
  });

  testWidgets('AgentAvatar passes the colour override to the avatar',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Center(
          child: AgentAvatar(
            state: AgentState.idle,
            size: 40,
            showGlow: false,
            colorOverride: Color(0xFFFF8800),
          ),
        ),
      ),
    );
    final avatar =
        tester.widget<EmojiBlendingAvatar>(find.byType(EmojiBlendingAvatar));
    expect(avatar.colorOverride, const Color(0xFFFF8800));
    expect(avatar.showGlow, isFalse);
    await tester.pumpWidget(const SizedBox());
  });
}
