// Pin operations batch reorder changes so pinned notes move as a group.
import 'package:notepad/core/database/app_data.dart';

/// Service for handling pin-related operations on notes, including bulk updates.
class PinOperationsService {
  /// Toggles the pin state of a single [note] and updates its timestamp.
  static NotesSection togglePinState(NotesSection note) {
    note
      ..isPinned = !note.isPinned
      ..updatedAt = DateTime.now();
    return note;
  }

  /// Processes a bulk pin/unpin operation for a set of [targetIds].
  ///
  /// It updates the [isPinned] status and [positionIndex] of each affected note
  /// within the [activeNotes] list. Pinned notes are grouped at the start of
  /// the list, while unpinned notes are moved to the end.
  ///
  /// Returns a map of note IDs to their updated [NotesSection] objects for database persistence.
  static Map<String, NotesSection> processBulkPin({
    required List<NotesSection> activeNotes,
    required Set<String> targetIds,
    required bool goalState,
    required int currentPinnedCount,
  }) {
    final Map<String, NotesSection> dbUpdates = {};

    // Start indexing from the end of current pins if pinning,
    // or use a negative offset if unpinning to push to the bottom.
    int positionCounter = goalState ? currentPinnedCount : -targetIds.length;

    for (final note in activeNotes) {
      if (targetIds.contains(note.id)) {
        togglePinState(note);
        note
          .positionIndex = positionCounter++;

        dbUpdates[note.id] = note;
      }
    }

    return dbUpdates;
  }
}
