import 'package:flutter/material.dart';
import 'package:notepad/core/database/app_data.dart';

// Manages which notes are selected and whether selection mode is active.
class SelectionController extends ChangeNotifier {
  Set<String> _selectedIds = {};

  Set<String> get selectedIds => _selectedIds;
  bool get isSelectionMode => _isSelectionMode;
  bool get hasSelection => _selectedIds.isNotEmpty;
  int get selectionCount => _selectedIds.length;

  bool isNoteSelected(String id) => _selectedIds.contains(id);
  bool _isSelectionMode = false;

  bool areAllSelected(List<NotesSection> activeNotes) {
    return activeNotes.isNotEmpty &&
        activeNotes.every((note) => _selectedIds.contains(note.id));
  }

  void enterSelectionMode() {
    if (!_isSelectionMode) {
      _isSelectionMode = true;
      notifyListeners();
    }
  }

  void exitSelectionMode() {
    _isSelectionMode = false;
    _selectedIds.clear();
    notifyListeners();
  }

  void toggleSelected(String noteId) {
    if (_selectedIds.contains(noteId)) {
      _selectedIds.remove(noteId);
    } else {
      _selectedIds.add(noteId);
    }

    if (_selectedIds.isNotEmpty) {
      _isSelectionMode = true;
    } else {
      _isSelectionMode = false;
    }
    notifyListeners();
  }

  void setSelectAll(List<NotesSection> activeNotes, bool selected) {
    if (selected) {
      _isSelectionMode = true;
      _selectedIds = activeNotes.map((note) => note.id).toSet();
    } else {
      _selectedIds.clear();
    }
    notifyListeners();
  }

  void clearSelection() {
    if (_selectedIds.isEmpty) return;

    _selectedIds.clear();
    notifyListeners();
  }

  void removeIds(Iterable<String> idsToRemove) {
    _selectedIds.removeAll(idsToRemove);

    if (_selectedIds.isEmpty) {
      _isSelectionMode = false;
    }
    notifyListeners();
  }
}
