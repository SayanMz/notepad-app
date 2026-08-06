// Facilitates the reconciliation of cloud-backed note snapshots with local storage.
import 'package:notepad/core/database/app_data.dart';

/// Service responsible for analyzing incoming backup data and determining which
/// notes need to be synchronized with local storage.
///
/// This service implements a "Safe Import" strategy that prioritizes local data integrity
/// by identifying new notes while avoiding the overwriting of existing local entries.
class BackupSyncService {
  /// Analyzes [cloudNotes] against the current local state to calculate a set of updates.
  ///
  /// The [localNoteLookup] function is used to check for the existence of notes by their ID.
  ///
  /// Returns a record containing:
  /// - [updates]: A map of note IDs to [NotesSection] objects that do not exist locally
  ///   and should be added.
  /// - [skippedCount]: The total number of notes that were already present on the device
  ///   and thus ignored to prevent data conflicts.
  static ({Map<String, NotesSection> updates, int skippedCount})
  calculateImportUpdates({
    required List<NotesSection> cloudNotes,
    required NotesSection? Function(String) localNoteLookup,
  }) {
    final Map<String, NotesSection> updates = {};
    int skippedCount = 0;

    for (final cloudNote in cloudNotes) {
      final localNote = localNoteLookup(cloudNote.id);

      // If the note already exists locally, we skip it to prevent accidental
      // regression or overwriting of local changes.
      if (localNote != null) {
        skippedCount++;
        continue;
      }

      // Identify new notes that are present in the cloud but missing locally.
      updates[cloudNote.id] = cloudNote;
    }

    return (updates: updates, skippedCount: skippedCount);
  }
}
