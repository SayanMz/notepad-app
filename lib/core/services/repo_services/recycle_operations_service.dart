import 'package:notepad/core/data/app_data.dart';

/// A Dart Record defining the exact payload returned after a bulk sweep
typedef BulkMoveResult = ({Map<String, NotesSection> dbUpdates});

class RecycleOperationsService {
  /// Performs a single O(N) sweep to transition notes between zones.
  /// Modifies the provided lists in-place for maximum memory efficiency.
  static BulkMoveResult processBulkMove({
    required List<NotesSection> currentActive,
    required List<NotesSection> currentDeleted,
    required Set<String> targetIds,
    required bool toDelete,
  }) {
    final idSet = targetIds;
    final Map<String, NotesSection> updates = {};

    if (toDelete) {
      currentActive.removeWhere((note) {
        if (idSet.contains(note.id)) {
          note.isDeleted = true;
          updates[note.id] = note;
          currentDeleted.add(note); // Move pointer to Trash
          return true;
        }
        return false;
      });
    } else {
      currentDeleted.removeWhere((note) {
        if (idSet.contains(note.id)) {
          note.isDeleted = false;
          updates[note.id] = note;
          currentActive.add(note); // Move pointer back to Home
          return true;
        }
        return false;
      });
    }

    return (dbUpdates: updates);
  }
}
