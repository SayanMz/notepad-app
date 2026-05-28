import 'package:notepad/core/data/app_data.dart';
import 'package:notepad/core/services/sqlite_fts_service.dart';

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
    final now = DateTime.now();

    if (toDelete) {
      currentActive.removeWhere((note) {
        if (idSet.contains(note.id)) {
          note.isDeleted = true;
          note.updatedAt = now;
          updates[note.id] = note;
          currentDeleted.add(note);
          SqliteFtsService.remove(note.id);
          return true;
        }
        return false;
      });
    } else {
      currentDeleted.removeWhere((note) {
        if (idSet.contains(note.id)) {
          note.isDeleted = false;
          note.updatedAt = now;
          updates[note.id] = note;
          currentActive.add(note); // Move pointer back to Home
          SqliteFtsService.insertOrUpdate(note.id, note.title, note.content);
          return true;
        }
        return false;
      });
    }

    return (dbUpdates: updates);
  }
}
