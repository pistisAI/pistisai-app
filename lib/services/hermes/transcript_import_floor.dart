/// Keeps a wiped chat from coming back from the agent runtime's transcript.
///
/// The local data wipe cannot delete the runtime's own copy of the chat. After
/// a wipe the app records the wipe time here, and the shared-channel sync only
/// imports runtime messages newer than that time.
library;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/message.dart';

/// Runtime messages strictly newer than [floor]; all of [harness] when
/// [floor] is null.
List<Message> transcriptAfterImportFloor(
  List<Message> harness,
  DateTime? floor,
) {
  if (floor == null) return harness;
  return harness.where((message) => message.timestamp.isAfter(floor)).toList();
}

/// Persists the time of the last local data wipe.
class TranscriptImportFloorStore {
  TranscriptImportFloorStore._();

  static const String preferenceKey = 'chat_transcript_import_floor';

  /// The recorded wipe time, or null when none is recorded or readable.
  static Future<DateTime?> read() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(preferenceKey);
      return raw == null ? null : DateTime.tryParse(raw);
    } catch (e) {
      debugPrint('[TranscriptImportFloor] Could not read: $e');
      return null;
    }
  }

  /// Records [floor]; returns false when it could not be saved.
  static Future<bool> write(DateTime floor) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return await prefs.setString(
        preferenceKey,
        floor.toUtc().toIso8601String(),
      );
    } catch (e) {
      debugPrint('[TranscriptImportFloor] Could not save: $e');
      return false;
    }
  }
}
