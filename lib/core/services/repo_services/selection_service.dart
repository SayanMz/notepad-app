import 'package:flutter/material.dart';
import 'package:notepad/core/data/app_data.dart';

class SelectionService {
  /// Pure logic: Returns a new Set with the ID either added or removed.
  static void toggleSelection(Set<String> currentSelection, String noteId) {
    if (currentSelection.contains(noteId)) {
      currentSelection.remove(noteId);
    } else {
      currentSelection.add(noteId);
    }
  }

  /// Instantly maps all active notes to a bulk selection set.
  static Set<String> selectAll(List<NotesSection> activeNotes) {
    return activeNotes.map((note) => note.id).toSet();
  }

  /// Applies a visual color update only to the selected entities.
  static void applyColorToSelection({
    required Set<String> selectedIds,
    required List<NotesSection> allNotes,
    required Color newColor,
  }) {
    for (final note in allNotes) {
      if (selectedIds.contains(note.id)) {
        note.cardColor = newColor;
      }
    }
  }
}
