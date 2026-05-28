import 'package:notepad/core/data/app_data.dart';

class PinOperationsService {
  /// Pure logic: Toggles the pin state of a single note and updates its timestamp.
  /// Returns the modified note so the repository can process the list shift.
  static NotesSection togglePinState(NotesSection note) {
    note.isPinned = !note.isPinned;
    note.updatedAt = DateTime.now();
    return note;
  }

  /// Processes a bulk pin/unpin operation in a single O(N) pass.
  /// Calculates exact positional indexing so newly pinned notes stack correctly.
  /// Returns a Map of all modified notes ready for a bulk database save.
  static Map<String, NotesSection> processBulkPin({
    required List<NotesSection> activeNotes,
    required Set<String> targetIds,
    required bool goalState,
    required int currentPinnedCount,
  }) {
    final Map<String, NotesSection> dbUpdates = {};

    // If we are pinning, we start counting from the bottom of the current pinned list.
    // If we are unpinning, their pin position doesn't matter (set to 0).
    int positionCounter = goalState ? currentPinnedCount : -targetIds.length;
    final now = DateTime.now();

    for (final note in activeNotes) {
      if (targetIds.contains(note.id)) {
        note.isPinned = goalState;
        note.updatedAt = now;

        // Stack the notes chronologically in the pinned zone
        note.positionIndex = positionCounter++;

        dbUpdates[note.id] = note;
      }
    }

    return dbUpdates;
  }
}
