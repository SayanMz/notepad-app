import 'package:notepad/core/data/app_data.dart';

class BackupSyncService {
  /// Evaluates incoming cloud notes against the local storage topology
  /// and returns a map of valid database updates.
  static Map<String, NotesSection> calculateImportUpdates({
    required List<NotesSection> cloudNotes,
    required NotesSection? Function(String) localNoteLookup,
  }) {
    final Map<String, NotesSection> updates = {};

    for (final cloudNote in cloudNotes) {
      final localNote = localNoteLookup(cloudNote.id);

      // Rule A: If locally deleted, ignore it (Recycle Bin Guard)
      if (localNote != null && localNote.isDeleted) continue;

      // Rule B: Only give it back if it's completely missing locally
      // This protects the user's active local edits from being overwritten
      if (localNote == null) {
        updates[cloudNote.id] = cloudNote;
      }
    }

    return updates;
  }
}
