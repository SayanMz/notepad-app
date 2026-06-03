// Pin operations batch reorder changes so pinned notes move as a group.
import 'package:notepad/core/database/app_data.dart';

class PinOperationsService {
  static NotesSection togglePinState(NotesSection note) {
    note.isPinned = !note.isPinned;
    note.updatedAt = DateTime.now();
    return note;
  }

  static Map<String, NotesSection> processBulkPin({
    required List<NotesSection> activeNotes,
    required Set<String> targetIds,
    required bool goalState,
    required int currentPinnedCount,
  }) {
    final Map<String, NotesSection> dbUpdates = {};

    int positionCounter = goalState ? currentPinnedCount : -targetIds.length;
    final now = DateTime.now();

    for (final note in activeNotes) {
      if (targetIds.contains(note.id)) {
        note.isPinned = goalState;
        note.updatedAt = now;

        note.positionIndex = positionCounter++;

        dbUpdates[note.id] = note;
      }
    }

    return dbUpdates;
  }
}
