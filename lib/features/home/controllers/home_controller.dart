import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:notepad/core/constants/animation_constants.dart';
import 'package:notepad/core/database/app_data.dart';
import 'package:notepad/core/database/notes_repository.dart';
import 'package:notepad/core/services/ui_management/scaffold_messenger_notifier.dart';
import 'package:notepad/features/home/controllers/animation_controller.dart';
import 'package:notepad/features/home/controllers/selection_controller.dart';
import 'package:notepad/features/home/home_constants.dart';
import 'package:notepad/features/home/controllers/auth_controller.dart';
import 'package:notepad/features/home/services/google_drive_service.dart';
import 'package:notepad/core/services/note_document_service.dart';

// Coordinates the home screen list, selection, drag, and deletion flows.
class HomeController extends ChangeNotifier {
  final SelectionController selectionController = SelectionController();
  final AnimationControllerState animationController =
      AnimationControllerState();
  final AuthController authController = AuthController();

  final ValueNotifier<int> colorChangeNotifier = ValueNotifier<int>(0);

  final ValueNotifier<bool> isSavingNotifier = ValueNotifier(false);
  final ValueNotifier<String> syncStatusNotifier = ValueNotifier(
    'Ready to sync',
  );
  final ValueNotifier<Color?> statusColorNotifier = ValueNotifier(null);
  Timer? _statusTimer;

  final ValueNotifier<bool> isFabExtended = ValueNotifier(true);
  final ValueNotifier<double> fabAlignX = ValueNotifier(0.0);
  double _accumulatedDelta = 0.0;

  List<NotesSection> get activeNotes => noteRepository.activeNotes;

  List<NotesSection> get selectedNotes => activeNotes
      .where((note) => selectionController.selectedIds.contains(note.id))
      .toList();

  bool get showPinAction => selectedNotes.any((n) => !n.isPinned);

  List<NotesSection> get pinnedNotes => noteRepository.pinnedNotes;
  List<NotesSection> get unpinnedNotes => noteRepository.unpinnedNotes;
  bool get hasActiveNotes => noteRepository.activeNotes.isNotEmpty;

  HomeController() {
    authController.initialize();
    selectionController.addListener(notifyListeners);
    animationController.addListener(notifyListeners);
    noteRepository.activeRevision.addListener(notifyListeners);
  }

  @override
  void dispose() {
    noteRepository.activeRevision.removeListener(notifyListeners);
    selectionController.removeListener(notifyListeners);
    animationController.removeListener(notifyListeners);
    super.dispose();
  }

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

  void togglePin(String noteId) async {
    await noteRepository.togglePinStatus(noteId);
  }

  Future<void> togglePinBulk() async {
    await noteRepository.togglePinBulk(
      selectedNotes.map((n) => n.id).toSet(),
      showPinAction,
    );
    notifyListeners();
  }

  void updateSelectedColors(Color color) {
    noteRepository.applyColorToSelection(
      selectionController.selectedIds,
      color,
    );
    colorChangeNotifier.value++;
  }

  Map<String, Color> getSelectedColorsSnapshot() {
    return {
      for (final id in selectionController.selectedIds)
        if (noteRepository.findById(id) case final note?) id: note.cardColor,
    };
  }

  void saveColors() =>
      noteRepository.saveColorsBulk(selectionController.selectedIds);

  void restoreColors(Map<String, Color> originalColors) {
    noteRepository.restoreColors(originalColors);
    colorChangeNotifier.value++;
  }

  bool isDraggingNote = false;

  void setDraggingState(bool dragging) {
    isDraggingNote = dragging;
    notifyListeners();
  }

  Future<void> executeBulkDelete() async {
    if (selectionController.selectedIds.isEmpty) return;

    final movedNoteIds = selectionController.selectedIds.toSet();
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
      await NoteDocumentService.shareNotesAsHTML(
        selectedNotes,
        text: 'Sharing ${selectedNotes.length} Notes',
      );
    } catch (e) {
      onError(e.toString());
    }
  }

  void updateFabState({required bool extend}) {
    if (isFabExtended.value == extend) return;
    isFabExtended.value = extend;
    fabAlignX.value = extend
        ? HomeConstants.fabAlignExpandedX
        : HomeConstants.fabAlignCollapsedX;
  }

  void handlePinnedReorder(int oldIndex, int newIndex) {
    noteRepository.reorderPinnedNotes(oldIndex, newIndex);
  }

  void handleUnpinnedReorder(int oldIndex, int newIndex) {
    noteRepository.reorderUnpinnedNotes(oldIndex, newIndex);
  }

  void handleTogglePin(String id) {
    noteRepository.togglePinStatus(id);
  }

  bool handleFabScroll(Notification notification) {
    if (selectionController.isSelectionMode) return false;

    if (notification is UserScrollNotification &&
        notification.direction == ScrollDirection.idle) {
      _accumulatedDelta = 0.0;
      return true;
    }

    if (notification is ScrollUpdateNotification) {
      if (notification.metrics.pixels <= HomeConstants.homeTopSnapThreshold) {
        updateFabState(extend: true);
        _accumulatedDelta = 0.0;
        return true;
      }

      if (notification.metrics.outOfRange) return false;

      final double delta = notification.scrollDelta ?? 0.0;

      if ((delta > 0 && _accumulatedDelta < 0) ||
          (delta < 0 && _accumulatedDelta > 0)) {
        _accumulatedDelta = 0.0;
      }

      _accumulatedDelta += delta;

      const double threshold = HomeConstants.homeBulkDeleteThreshold;

      if (_accumulatedDelta > threshold) {
        updateFabState(extend: false);
        _accumulatedDelta = 0.0;
      } else if (_accumulatedDelta < -threshold) {
        updateFabState(extend: true);
        _accumulatedDelta = 0.0;
      }
    }

    return true;
  }

  void updateSyncStatus(String message, {Color? color}) {
    _statusTimer?.cancel();
    syncStatusNotifier.value = message;
    statusColorNotifier.value = color;

    _statusTimer = Timer(AnimationConstants.snackbarLong, () {
      syncStatusNotifier.value = 'Ready to sync';
      statusColorNotifier.value = null;
    });
  }

  Future<void> executeBackup() async {
    try {
      isSavingNotifier.value = true;

      final jsonString = await noteRepository.exportNotesToBackupString();
      await googleDriveService.uploadBackup(jsonString);
      await authController.fetchFreshStorageStats();

      updateSyncStatus('All saved', color: Colors.green);
      debugPrint('Manual backup completed successfully.');
    } catch (e) {
      updateSyncStatus('Sync failed', color: Colors.redAccent);
      showErrorSnackBar('$e');
    } finally {
      isSavingNotifier.value = false;
    }
  }

  Future<void> executeRestore() async {
    try {
      isSavingNotifier.value = true;

      final backupJson = await googleDriveService.downloadBackup();
      if (backupJson == null || backupJson.isEmpty) {
        updateSyncStatus('No backup found', color: Colors.orange);
        debugPrint('No valid backup found on Google Drive.');
        return;
      }

      await noteRepository.importNotesFromBackupString(backupJson);
      await authController.fetchFreshStorageStats();

      updateSyncStatus('All saved', color: Colors.green);
      debugPrint('Manual restore and data merge completed successfully.');
    } catch (e) {
      updateSyncStatus('Sync failed', color: Colors.redAccent);
      showErrorSnackBar('$e');
    } finally {
      isSavingNotifier.value = false;
    }
  }
}
