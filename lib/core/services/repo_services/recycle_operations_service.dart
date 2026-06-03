// Recycle operations move notes between active and deleted collections in bulk.
import 'package:notepad/core/database/app_data.dart';
import 'package:notepad/core/database/sqlite_fts_service.dart';

typedef BulkMoveResult = ({Map<String, NotesSection> dbUpdates});

class RecycleOperationsService {
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
          currentActive.add(note);
          SqliteFtsService.insertOrUpdate(note.id, note.title, note.content);
          return true;
        }
        return false;
      });
    }

    return (dbUpdates: updates);
  }
}
