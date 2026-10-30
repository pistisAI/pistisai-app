import 'package:pistisai/services/voice/voice_conversation_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('VoiceConversationService', () {
    late VoiceConversationService voiceConversationService;

    setUp(() {
      voiceConversationService = VoiceConversationService(
        config: const VoiceConversationConfig(
          engagedHold: Duration(milliseconds: 200),
        ),
      );
    });

    tearDown(() {
      voiceConversationService.dispose();
    });

    test('starts in idle mode', () {
      expect(voiceConversationService.snapshot.mode,
          VoiceConversationMode.idle);
    });

    test('noteWakePhrase changes to engaged mode', () {
      voiceConversationService.noteWakePhrase('hello');
      expect(voiceConversationService.snapshot.mode,
          VoiceConversationMode.engaged);
      expect(voiceConversationService.snapshot.isEngaged, isTrue);
    });

    test('buildFastAcknowledgement returns response for heard query', () {
      final ack = voiceConversationService
          .buildFastAcknowledgement('Hermes can you hear me?');
      expect(ack, isNotNull);
    });

    test('shouldPreferConversationalPath returns true when engaged', () {
      voiceConversationService.noteWakePhrase('hello');
      expect(
          voiceConversationService.shouldPreferConversationalPath('test'),
          isTrue);
    });
  });
}
