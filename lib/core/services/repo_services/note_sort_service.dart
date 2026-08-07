// Centralized sorting logic for managing note ordering across active and deleted views.
import 'package:notepad/core/database/app_data.dart';

/// Service responsible for maintaining a stable and predictable order for notes.
///
/// It leverages a hybrid sorting approach:
/// 1. **Pinning State**: Pinned notes always appear at the top.
/// 2. **Manual Ordering**: Uses `positionIndex` for user-defined drag-and-drop order.
/// 3. **Creation Time (ULID)**: Uses the lexicographical nature of ULIDs to sort by
///    time when manual indices are equal (newest first).
class NoteSortService {
  /// Sorts a list of active notes in-place following the hierarchy:
  /// Pinned status > Manual positionIndex > Reverse ID (Creation time).
  static void sortActiveNotes(List<NotesSection> notes) {
    notes.sort((a, b) {
      // 1. Pinned notes float to the top
      if (a.isPinned != b.isPinned) return a.isPinned ? -1 : 1;

      // 2. Tie-break with manual positionIndex (lower index = higher in list)
      int posCmp = a.positionIndex.compareTo(b.positionIndex);
      if (posCmp != 0) return posCmp;

      // 3. Final tie-break: Reverse ID sort. Since we use ULIDs, b.compareTo(a)
      // effectively places the most recently created notes first.
      return b.id.compareTo(a.id);
    });
  }

  /// Sorts deleted notes (trash) by creation time only.
  ///
  /// We ignore pinning and manual reordering in the trash; users typically
  /// expect to see their most recently worked-on items at the top.
  static void sortDeletedNotes(List<NotesSection> notes) {
    // Reverse ULID comparison for "Newest First" view.
    notes.sort((a, b) => b.id.compareTo(a.id));
  }

  /// Finds the correct insertion point for a single note and inserts it.
  ///
  /// This is used for new note creation or status toggling to avoid
  /// the performance cost of a full `.sort()` on the entire collection.
  ///
  /// If [atIndex] is provided, it skips the search logic and performs a direct
  /// insertion at that specific list index (e.g. when inserting a new note).
  static int insertSorted(
    List<NotesSection> list,
    NotesSection note, {
    int? atIndex,
  }) {
    if (atIndex != null) {
      list.insert(atIndex, note);
      return atIndex;
    }

    final index = list.indexWhere((other) {
      // Logic mirrors sortActiveNotes comparison
      if (note.isPinned != other.isPinned) return note.isPinned;
      int posCmp = note.positionIndex.compareTo(other.positionIndex);
      if (posCmp != 0) return posCmp < 0;
      return note.id.compareTo(other.id) > 0;
    });

    if (index == -1) {
      list.add(note);
      return list.length - 1;
    } else {
      list.insert(index, note);
      return index;
    }
  }

  /// Handles drag-and-drop reordering within a specific zone (Pinned or Unpinned).
  ///
  /// [zoneList] is the specific subset (Pinned or Others) being reordered.
  /// [pinnedCount] is used as a coordinate offset to ensure unpinned notes
  /// always have a higher `positionIndex` than pinned ones in the master list.
  static Map<String, NotesSection> reorderZone({
    required List<NotesSection> activeNotes,
    required List<NotesSection> zoneList,
    required int oldIndex,
    required int newIndex,
    required bool isPinnedZone,
    required int pinnedCount,
  }) {
    // 1. Physically move the item in the local mutable copy
    final movingNote = zoneList.removeAt(oldIndex);
    zoneList.insert(newIndex, movingNote);

    // 2. Determine the starting offset for position indices
    final int indexOffset = isPinnedZone ? 0 : pinnedCount;

    // 3. Batch process the new indices to be synced to the database
    final Map<String, NotesSection> bulkUpdates = {};
    for (int i = 0; i < zoneList.length; i++) {
      zoneList[i].positionIndex = indexOffset + i;
      bulkUpdates[zoneList[i].id] = zoneList[i];
    }

    return bulkUpdates;
  }
}
