// Backup sync reconciles imported snapshots with the local note set.
import 'package:notepad/core/database/app_data.dart';

class BackupSyncService {
  static ({Map<String, NotesSection> updates, int skippedCount})
  calculateImportUpdates({
    required List<NotesSection> cloudNotes,
    required NotesSection? Function(String) localNoteLookup,
  }) {
    final Map<String, NotesSection> updates = {};
    int skippedCount = 0;

    for (final cloudNote in cloudNotes) {
      final localNote = localNoteLookup(cloudNote.id);

      if (localNote != null) {
        skippedCount++;
        continue;
      }

      if (localNote == null) {
        updates[cloudNote.id] = cloudNote;
      }
    }

    return (updates: updates, skippedCount: skippedCount);
  }
}
