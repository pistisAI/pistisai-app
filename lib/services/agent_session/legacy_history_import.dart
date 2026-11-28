import '../../models/message.dart';
import '../hermes/transcript_import_floor.dart';

/// Selects the legacy Hermes rows to copy into a channel once (#1067, Q2).
///
/// Returns null when the transcript could not be read, so the caller retries
/// later. An empty list means there is nothing to copy (including after a
/// wipe, and when the import already happened).
List<Message>? legacyHistoryToImport({
  required bool alreadyImported,
  required List<Message>? transcript,
  required DateTime? floor,
}) {
  if (alreadyImported) return const [];
  if (transcript == null) return null;
  return transcriptAfterImportFloor(transcript, floor);
}
