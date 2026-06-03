// Sort helpers keep pinned, unpinned, and deleted ordering stable.
import 'package:notepad/core/database/app_data.dart';

class NoteSortService {
  static void sortActiveNotes(List<NotesSection> notes) {
    notes.sort((a, b) {
      if (a.isPinned != b.isPinned) return a.isPinned ? -1 : 1;

      int posCmp = a.positionIndex.compareTo(b.positionIndex);
      if (posCmp != 0) return posCmp;

      return b.updatedAt.compareTo(a.updatedAt);
    });
  }

  static void sortDeletedNotes(List<NotesSection> notes) {
    notes.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  static int insertSorted(List<NotesSection> list, NotesSection note) {
    final index = list.indexWhere((other) {
      if (note.isPinned != other.isPinned) return note.isPinned;
      int posCmp = note.positionIndex.compareTo(other.positionIndex);
      if (posCmp != 0) return posCmp < 0;
      return note.updatedAt.isAfter(other.updatedAt);
    });

    if (index == -1) {
      list.add(note);
      return list.length - 1;
    } else {
      list.insert(index, note);
      return index;
    }
  }

  static Map<String, NotesSection> reorderZone({
    required List<NotesSection> activeNotes,
    required List<NotesSection> zoneList,
    required int oldIndex,
    required int newIndex,
    required bool isPinnedZone,
    required int pinnedCount,
  }) {
    final movingNote = zoneList.removeAt(oldIndex);
    zoneList.insert(newIndex, movingNote);

    final int indexOffset = isPinnedZone ? 0 : pinnedCount;

    final Map<String, NotesSection> bulkUpdates = {};
    for (int i = 0; i < zoneList.length; i++) {
      zoneList[i].positionIndex = indexOffset + i;
      bulkUpdates[zoneList[i].id] = zoneList[i];
    }

    return bulkUpdates;
  }
}
