import 'package:flutter/material.dart';
import 'package:notepad/core/data/app_data.dart';
import 'package:notepad/core/services/repo_services/selection_service.dart';

/// ------------------------------------------------------------
/// SELECTION CONTROLLER (UI State)
/// Tracks active selections. Completely decoupled from the DB.
/// ------------------------------------------------------------
class SelectionController extends ChangeNotifier {
  Set<String> _selectedIds = {};

  Set<String> get selectedIds => _selectedIds;
  bool get hasSelection => _selectedIds.isNotEmpty;
  int get selectionCount => _selectedIds.length;

  bool isNoteSelected(String id) => _selectedIds.contains(id);

  bool areAllSelected(List<NotesSection> activeNotes) {
    return activeNotes.isNotEmpty &&
        activeNotes.every((note) => _selectedIds.contains(note.id));
  }

  void toggleSelected(String noteId) {
    // Modifies the _selectedIds set in-place instantly
    SelectionService.toggleSelection(_selectedIds, noteId);
    notifyListeners();
  }

  void setSelectAll(List<NotesSection> activeNotes, bool selected) {
    if (selected) {
      _selectedIds = SelectionService.selectAll(activeNotes);
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

  /// Called after bulk operations to remove processed items from selection
  void removeIds(Iterable<String> idsToRemove) {
    _selectedIds.removeAll(idsToRemove);
    if (_selectedIds.isEmpty) notifyListeners();
  }
}
