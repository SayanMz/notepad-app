import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:notepad/core/data/app_data.dart';
import 'package:notepad/core/data/notes_repository.dart';
import 'package:notepad/core/services/scaffold_messenger_notifier.dart';
import 'package:notepad/features/home/services/auth_controller.dart';
import 'package:notepad/features/home/services/google_drive_service.dart';
import 'package:notepad/features/note/services/note_document_service.dart';

class HomeController extends ChangeNotifier {
  List<NotesSection> get activeNotes => noteRepository.activeNotes;
  List<NotesSection> get selectedNotes => noteRepository.selectedNotes;

  bool get isSelectionMode => selectedNotes.isNotEmpty;
  bool get isAllSelected => noteRepository.areAllActiveNotesSelected;
  // If at least one selected note is NOT pinned, we show the 'Pin' action
  bool get showPinAction => selectedNotes.any((n) => !n.isPinned);
  bool isNoteSelected(String id) => noteRepository.isNoteSelected(id);

  final AuthController authController = AuthController();
  Timer? _statusTimer;

  HomeController() {
    authController.initialize();
  }

  // 1. Loading & Sync Status Notifiers
  final ValueNotifier<bool> isSavingNotifier = ValueNotifier(false);
  final ValueNotifier<String> syncStatusNotifier = ValueNotifier(
    'Ready to sync',
  );
  final ValueNotifier<Color?> statusColorNotifier = ValueNotifier(null);

  // 2. FAB & Navigation State
  final ValueNotifier<bool> isFabExtended = ValueNotifier(true);
  final ValueNotifier<double> fabAlignX = ValueNotifier(0.0);

  double _accumulatedDelta = 0.0;

  Future<void> showSingleDeleteSnackbar(String noteId) async {
    final note = noteRepository.findById(noteId);
    if (note == null) return;

    await noteRepository.toggleDeletedStatus(noteId, true);
    showRestorationSnackBar(
      undoLabel: 'Restore',
      message:
          '${note.title.isEmpty ? "Note" : note.title} moved to recycle bin',
      onUndo: () async {
        // Use toggleDeletedStatus for consistency
        await noteRepository.toggleDeletedStatus(noteId, false);
      },
    );
  }

  void toggleSelectAll(bool? value) {
    final bool newValue = value ?? false;
    noteRepository.setSelectAllForAllActiveNotes(value ?? false);
    if (newValue) {
      HapticFeedback.mediumImpact();
    } else {
      HapticFeedback.lightImpact();
    }
  }

  void updateSelectedColors(Color color) {
    // 1. Perform the action
    noteRepository.updateColorForSelectedNotes(color);

    // 2. Provide physical feedback for the color change
    HapticFeedback.selectionClick();
  }

  // Pass a navigation callback instead of BuildContext
  Future<void> openNote({
    String? noteId,
    required Future<void> Function(String?) onNavigate,
  }) async {
    uiNotifier.clearSnackBars();
    await onNavigate(noteId);
  }

  Future<void> togglePin(String noteId) async {
    await noteRepository.togglePinStatus(noteId);
  }

  // Pass an error-handling callback instead of checking context.mounted
  Future<void> shareSelectedNotes({
    required void Function(String) onError,
  }) async {
    final selectedNotes = noteRepository.selectedNotes;
    if (selectedNotes.isEmpty) return;

    try {
      await NoteDocumentService.shareNotesAsHTML(
        selectedNotes,
        text: 'Sharing ${selectedNotes.length} Notes',
      );
    } catch (e) {
      // The controller doesn't care HOW the error is shown, it just passes it back
      onError(e.toString());
    }
  }

  void saveColors() => noteRepository.saveSelectedColors();
  void restoreColors(Map<String, Color> originalColors) {
    noteRepository.restoreColors(originalColors);
  }

  Future<void> togglePinBulk() async {
    await noteRepository.togglePinBulk(showPinAction);
  }

  Future<void> flushPendingPinnedWrites() async {
    await noteRepository.flushPendingPinnedWrites();
  }

  Future<void> deleteSelected(List<NotesSection> notes) async {
    if (notes.isEmpty) return;

    final movedNoteIds = notes.map((n) => n.id).toList();
    noteRepository.toggleDeletedStatusBulk(movedNoteIds, true);

    showRestorationSnackBar(
      undoLabel: 'Restore',
      message:
          '${notes.length} ${notes.length == 1 ? 'note' : 'notes'} moved to recycle bin',
      onUndo: () async {
        // Use the bulk method instead of a loop!
        await noteRepository.toggleDeletedStatusBulk(movedNoteIds, false);
      },
    );
  }

  // 2. BULK DELETE EXECUTION
  void executeBulkDelete() {
    if (selectedNotes.isEmpty) return;
    final selected = selectedNotes;

    noteRepository.clearSelection();
    deleteSelected(selected);
    HapticFeedback.heavyImpact(); // Premium feel for deletion
  }

  void updateSyncStatus(String message, {Color? color, bool temporary = true}) {
    _statusTimer?.cancel();
    syncStatusNotifier.value = message;
    statusColorNotifier.value = color;

    if (temporary) {
      _statusTimer = Timer(const Duration(seconds: 3), () {
        syncStatusNotifier.value = 'Ready to sync';
        statusColorNotifier.value = null;
      });
    }
  }

  Future<void> runManualBackup() async {
    try {
      final jsonString = await noteRepository.exportNotesToBackupString();
      await googleDriveService.uploadBackup(jsonString);
      debugPrint('Manual backup completed successfully.');
    } catch (e) {
      showErrorSnackBar('$e');
      rethrow;
    }
  }

  Future<void> runManualRestore() async {
    try {
      final backupJson = await googleDriveService.downloadBackup();
      if (backupJson == null || backupJson.isEmpty) {
        debugPrint('No valid backup found on Google Drive.');
        return;
      }

      await noteRepository.importNotesFromBackupString(backupJson);
      debugPrint('Manual restore and data merge completed successfully.');
    } catch (e) {
      showErrorSnackBar('$e');
      rethrow;
    }
  }

  // inside HomeController class

  void updateFabState({required bool extend}) {
    if (isFabExtended.value == extend) return;
    isFabExtended.value = extend;
    fabAlignX.value = extend ? 0.0 : 0.95;
  }

  // 1. SCROLL LOGIC
  bool handleFabScroll(
    Notification notification,
    Size screenSize,
    bool isSelectionMode,
  ) {
    if (isSelectionMode) return false;

    if (notification is ScrollNotification && notification.metrics.outOfRange) {
      _accumulatedDelta = 0.0;
      return false;
    }

    if (notification is ScrollUpdateNotification) {
      final double delta = notification.scrollDelta ?? 0.0;
      final double threshold = screenSize.height * 0.10;
      final double offset = notification.metrics.pixels;

      if (offset <= 10) {
        _accumulatedDelta = 0.0;
        updateFabState(extend: true); // Your existing fab state logic
        return true;
      }

      if ((delta > 0 && _accumulatedDelta < 0) ||
          (delta < 0 && _accumulatedDelta > 0)) {
        _accumulatedDelta = delta;
      } else {
        _accumulatedDelta += delta;
      }

      if (_accumulatedDelta > threshold) {
        updateFabState(extend: false);
        _accumulatedDelta = 0.0;
      } else if (_accumulatedDelta < -threshold) {
        updateFabState(extend: true);
        _accumulatedDelta = 0.0;
      }
    }

    if (notification is UserScrollNotification &&
        notification.direction == ScrollDirection.idle) {
      _accumulatedDelta = 0.0;
    }
    return true;
  }

  // 3. CLOUD ACTION WRAPPER
  Future<void> runCloudOperation({
    required Future<void> Function() action,
    required ValueNotifier<bool> loadingNotifier,
    required Function(String, Color?) onStatusUpdate,
  }) async {
    try {
      loadingNotifier.value = true;
      await action();
      await authController.fetchFreshStorageStats();
      onStatusUpdate('All saved', Colors.green);
    } catch (e) {
      onStatusUpdate('Sync failed', Colors.redAccent);
      rethrow;
    } finally {
      loadingNotifier.value = false;
    }
  }
}
