import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:notepad/core/database/app_data.dart';
import 'package:notepad/core/database/notes_repository.dart';
import 'package:notepad/core/services/ui_management/scaffold_messenger_notifier.dart';
import 'package:notepad/features/home/controllers/animation_controller.dart';
import 'package:notepad/features/home/controllers/selection_controller.dart';
import 'package:notepad/features/home/services/note_html_exporter.dart';

// Coordinates home note actions such as selection, sharing, and deletion.
class HomeController extends ChangeNotifier {
  final SelectionController selectionController;
  final AnimationControllerState animationController;
  final ScrollController _scrollController;
  final NoteRepository noteRepository;

  HomeController({
    required this.selectionController,
    required this.animationController,
    ScrollController? scrollController,
    NoteRepository? noteRepository,
  }) : _scrollController = scrollController ?? ScrollController(),
       noteRepository = noteRepository ?? NoteRepository() {
    this.noteRepository.activeRevision.addListener(_proxyListener);
    this.noteRepository.activeRevision.addListener(_handleEmptyState);
    _runMaintenance();
  }

  void _runMaintenance() {
    // Skip deferred maintenance in widget tests to avoid dangling timers.
    if (!(!kIsWeb && Platform.environment.containsKey('FLUTTER_TEST'))) {
      // Defer maintenance until the home page is completely idle
      SchedulerBinding.instance.scheduleTask(() {
        noteRepository.runPostStartupMaintenance();
      }, Priority.idle);
    }
  }

  // When all notes are bulk-deleted and user is stuck halfway down the notes list
  void _handleEmptyState() {
    if (!hasActiveNotes && _scrollController.hasClients) {
      if (_scrollController.offset > 0) {
        _scrollController.jumpTo(0.0);
      }
    }
  }

  void _proxyListener() {
    notifyListeners();
  }

  final ValueNotifier<int> colorChangeNotifier = ValueNotifier<int>(0);

  Set<String> get selectedIds => selectionController.selectedIds;
  List<NotesSection> get activeNotes => noteRepository.activeNotes;
  List<NotesSection> get selectedNotes =>
      activeNotes.where((note) => selectedIds.contains(note.id)).toList();
  List<NotesSection> get pinnedNotes => noteRepository.pinnedNotes;
  List<NotesSection> get unpinnedNotes => noteRepository.unpinnedNotes;

  bool get showPinAction => selectedNotes.any((n) => !n.isPinned);
  bool get hasActiveNotes => noteRepository.activeNotes.isNotEmpty;

  void toggleSelectAll(bool? value) {
    final bool newValue = value ?? false;

    selectionController.setSelectAll(activeNotes, newValue);
    if (newValue) {
      HapticFeedback.mediumImpact();
    }
  }

  Future<void> openNote({
    String? noteId,
    required Future<void> Function(String?) onNavigate,
  }) async {
    uiNotifier.clearSnackBars();
    await onNavigate(noteId);
  }

  Future<void> togglePin(String noteId) =>
      noteRepository.togglePinStatus(noteId);

  Future<void> togglePinBulk() => noteRepository.togglePinBulk(
    selectedNotes.map((n) => n.id).toSet(),
    showPinAction,
  );

  void updateSelectedColors(Color color) {
    noteRepository.applyColorToSelection(selectedIds, color);
    colorChangeNotifier.value++;
  }

  Map<String, Color> getSelectedColorsSnapshot() {
    return {
      for (final id in selectedIds)
        if (noteRepository.findById(id) case final note?) id: note.cardColor,
    };
  }

  void saveColors() => noteRepository.saveColorsBulk(selectedIds);

  void restoreColors(Map<String, Color> originalColors) {
    noteRepository.restoreColors(originalColors);
    colorChangeNotifier.value++;
  }

  Future<void> executeBulkDelete() async {
    if (selectedIds.isEmpty) return;

    final movedNoteIds = Set<String>.from(selectedIds);
    final int selectedCount = movedNoteIds.length;

    await animationController.triggerVaporizeAnimation(movedNoteIds);
    await noteRepository.toggleDeletedStatusBulk(movedNoteIds, true);

    selectionController.exitSelectionMode();
    HapticFeedback.heavyImpact();

    showRestorationSnackBar(
      undoLabel: 'Restore',
      message:
          '$selectedCount ${selectedCount == 1 ? 'note' : 'notes'} moved to recycle bin',
      onUndo: () async {
        await noteRepository.toggleDeletedStatusBulk(movedNoteIds, false);
      },
    );
  }

  Future<void> executeSingleDelete(String noteId) async {
    final note = noteRepository.findById(noteId);
    if (note == null) return;

    await noteRepository.toggleDeletedStatus(noteId, true);
    showRestorationSnackBar(
      undoLabel: 'Restore',
      message:
          '${note.title.isEmpty ? "Note" : note.title} moved to recycle bin',
      onUndo: () async {
        await noteRepository.toggleDeletedStatus(noteId, false);
      },
    );
  }

  Future<void> shareSelectedNotes({
    required void Function(String) onError,
  }) async {
    final selectedNotes = this.selectedNotes;
    if (selectedNotes.isEmpty) return;

    try {
      await NoteHtmlExporter.shareNotesAsHTML(
        selectedNotes,
        text: 'Sharing ${selectedNotes.length} Notes',
      );
    } catch (e) {
      onError(e.toString());
    }
  }

  void handlePinnedReorder(int oldIndex, int newIndex) =>
      noteRepository.reorderPinnedNotes(oldIndex, newIndex);

  void handleUnpinnedReorder(int oldIndex, int newIndex) =>
      noteRepository.reorderUnpinnedNotes(oldIndex, newIndex);

  @override
  void dispose() {
    colorChangeNotifier.dispose();
    noteRepository.activeRevision.removeListener(_proxyListener);
    noteRepository.activeRevision.removeListener(_handleEmptyState);
    super.dispose();
  }
}
