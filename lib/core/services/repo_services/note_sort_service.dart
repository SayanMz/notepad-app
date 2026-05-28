import 'package:notepad/core/data/app_data.dart';

class NoteSortService {
  /// Sorts notes enforcing the strict hierarchy: Pinned -> Drag Rank -> Timestamp
  static void sortActiveNotes(List<NotesSection> notes) {
    notes.sort((a, b) {
      // TIER 1: Strict Pin Isolation (Pinned always stays on top)
      if (a.isPinned != b.isPinned) return a.isPinned ? -1 : 1; //

      // TIER 2: Positional Sorting (Applies to BOTH pinned and unpinned drag-and-drop lists)
      int posCmp = a.positionIndex.compareTo(b.positionIndex); //
      if (posCmp != 0) return posCmp; //

      // TIER 3: Chronological Fallback (If positional indices are tied or unassigned)
      return b.updatedAt.compareTo(a.updatedAt); //
    });
  }

  /// Sorts the recycle bin purely by chronological deletion time
  static void sortDeletedNotes(List<NotesSection> notes) {
    notes.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  /// Surgically inserts a single note into an already sorted list and returns the landing index
  static int insertSorted(List<NotesSection> list, NotesSection note) {
    final index = list.indexWhere((other) {
      if (note.isPinned != other.isPinned) return note.isPinned;
      int posCmp = note.positionIndex.compareTo(other.positionIndex);
      if (posCmp != 0) return posCmp < 0;
      return note.updatedAt.isAfter(other.updatedAt);
    });

    if (index == -1) {
      list.add(note);
      return list.length - 1; // Returns the very last index of the array
    } else {
      list.insert(index, note);
      return index; // Returns the exact landing spot
    }
  }

  /// Re-ranks notes based on manual user drag intent and applies the global sort rule.
  static Map<String, NotesSection> reorderZone({
    required List<NotesSection> activeNotes,
    required List<NotesSection> zoneList,
    required int oldIndex,
    required int newIndex,
    required bool isPinnedZone, // 🌟 NEW: Know which zone we are normalizing
    required int pinnedCount, // 🌟 NEW: Know where the pinned zone ends
  }) {
    // 1. Swap elements inside the sub-list copy
    final movingNote = zoneList.removeAt(oldIndex);
    zoneList.insert(newIndex, movingNote);

    // 2. Determine the starting offset barrier
    // If it's the pinned zone, start indexing at 0.
    // If it's the unpinned zone, start indexing right after the last pinned note!
    final int indexOffset = isPinnedZone ? 0 : pinnedCount;

    final Map<String, NotesSection> bulkUpdates = {};
    for (int i = 0; i < zoneList.length; i++) {
      // 🌟 FIXED: Indices are now completely unique across both sections!
      zoneList[i].positionIndex = indexOffset + i;
      bulkUpdates[zoneList[i].id] = zoneList[i];
    }

    return bulkUpdates;
  }
}
