import 'package:notepad/core/data/app_data.dart';

class NoteSortService {
  /// Sorts notes enforcing the strict hierarchy: Pinned -> Drag Rank -> Timestamp
  static void sortActiveNotes(List<NotesSection> notes) {
    notes.sort((a, b) {
      if (a.isPinned != b.isPinned) return a.isPinned ? -1 : 1;

      int posCmp = a.positionIndex.compareTo(b.positionIndex);
      if (posCmp != 0) return posCmp;
      //The most recently updated note will float to the top of any notes
      return b.updatedAt.compareTo(a.updatedAt);
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
}
