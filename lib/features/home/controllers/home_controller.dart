import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:notepad/core/constants/animation_constants.dart';
import 'package:notepad/features/home/home_constants.dart';
import 'package:notepad/core/data/app_data.dart';
import 'package:notepad/core/data/notes_repository.dart';
import 'package:notepad/core/services/scaffold_messenger_notifier.dart';
import 'package:notepad/features/home/services/auth_controller.dart';
import 'package:notepad/features/home/services/google_drive_service.dart';
import 'package:notepad/features/note/services/note_document_service.dart';
import 'package:notepad/features/home/controllers/animation_controller.dart';
import 'package:notepad/features/home/controllers/selection_controller.dart';

class HomeController extends ChangeNotifier {
  // ==========================================
  // 1. DEPENDENCIES & SUB-CONTROLLERS
  // ==========================================

  final SelectionController selectionController = SelectionController();
  final AnimationControllerState animationController =
      AnimationControllerState();
  final AuthController authController = AuthController();

  // ==========================================
  // 2. STATE NOTIFIERS & VARIABLES
  // ==========================================

  // Loading & Sync Status Notifiers
  final ValueNotifier<bool> isSavingNotifier = ValueNotifier(false);
  final ValueNotifier<String> syncStatusNotifier = ValueNotifier(
    'Ready to sync',
  );
  final ValueNotifier<Color?> statusColorNotifier = ValueNotifier(null);
  Timer? _statusTimer;

  // FAB & Navigation State
  final ValueNotifier<bool> isFabExtended = ValueNotifier(true);
  final ValueNotifier<double> fabAlignX = ValueNotifier(0.0);
  double _accumulatedDelta = 0.0;

  // ==========================================
  // 3. COMPUTED PROPERTIES (GETTERS)
  // ==========================================

  List<NotesSection> get activeNotes => noteRepository.activeNotes;

  List<NotesSection> get selectedNotes => activeNotes
      .where((note) => selectionController.selectedIds.contains(note.id))
      .toList();

  bool get isSelectionMode => selectionController.hasSelection;
  bool get isAllSelected => selectionController.areAllSelected(activeNotes);

  // If at least one selected note is NOT pinned, we show the 'Pin' action
  bool get showPinAction => selectedNotes.any((n) => !n.isPinned);

  bool isNoteSelected(String id) => selectionController.isNoteSelected(id);
  bool isVaporizing(String id) => animationController.isVaporizing(id);

  // ==========================================
  // 4. LIFECYCLE (INIT & DISPOSE)
  // ==========================================

  HomeController() {
    authController.initialize();
    selectionController.addListener(notifyListeners);
    animationController.addListener(notifyListeners);
    noteRepository.activeRevision.addListener(notifyListeners);
  }

  @override
  void dispose() {
    // Clean up the listener when the controller dies
    noteRepository.activeRevision.removeListener(notifyListeners);
    selectionController.removeListener(notifyListeners);
    animationController.removeListener(notifyListeners);
    super.dispose();
  }

  // ==========================================
  // 5. SELECTION MANAGEMENT
  // ==========================================

  void toggleSelectAll(bool? value) {
    final bool newValue = value ?? false;
    selectionController.setSelectAll(activeNotes, newValue);
    if (newValue) {
      HapticFeedback.mediumImpact();
    } else {
      HapticFeedback.lightImpact();
    }
  }

  void clearSelection() {
    selectionController.clearSelection();
  }

  void toggleSelected(String noteId) {
    selectionController.toggleSelected(noteId);
  }

  // ==========================================
  // 6. NOTE DATA OPERATIONS
  // ==========================================

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

  Future<void> togglePinBulk() async {
    await noteRepository.togglePinBulk(
      selectedNotes.map((n) => n.id).toSet(),
      showPinAction,
    );
  }

  Future<void> flushPendingPinnedWrites() async {
    await noteRepository.flushPendingPinnedWrites();
  }

  void updateSelectedColors(Color color) {
    noteRepository.updateColorsBulk(selectionController.selectedIds, color);
    // Provide physical feedback for the color change
    HapticFeedback.selectionClick();
  }

  void saveColors() =>
      noteRepository.saveColorsBulk(selectionController.selectedIds);

  void restoreColors(Map<String, Color> originalColors) {
    noteRepository.restoreColors(originalColors);
  }

  Future<void> deleteSelected(List<NotesSection> notes) async {
    if (notes.isEmpty) return;

    final movedNoteIds = notes.map((n) => n.id).toSet();
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

  // BULK DELETE EXECUTION
  Future<void> executeBulkDelete() async {
    if (selectedNotes.isEmpty) return;

    // 1. Lock in a copy of the selected notes before altering state
    final selected = List<NotesSection>.from(selectedNotes);
    final selectedIds = selected.map((n) => n.id).toList();

    // 2. ⚡ Play the 300ms vaporize animation loop FIRST
    await animationController.triggerVaporizeAnimation(selectedIds);

    // 3. Once they shrink to 0.0, clear selection and execute the actual DB move
    selectionController.clearSelection();
    await deleteSelected(selected); // Triggers your SnackBar setup
    HapticFeedback.heavyImpact(); // Premium feel for deletion
  }

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

  // Pass an error-handling callback instead of checking context.mounted
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
      // The controller doesn't care HOW the error is shown, it just passes it back
      onError(e.toString());
    }
  }

  // ==========================================
  // 7. UI, SCROLL & ANIMATION LOGIC
  // ==========================================

  Future<void> triggerVaporizeAnimation(List<String> noteIds) async {
    await animationController.triggerVaporizeAnimation(noteIds);
  }

  void updateFabState({required bool extend}) {
    if (isFabExtended.value == extend) return;
    isFabExtended.value = extend;
    fabAlignX.value = extend
        ? HomeConstants.fabAlignExpandedX
        : HomeConstants.fabAlignCollapsedX;
  }

  // SCROLL LOGIC
  bool handleFabScroll(Notification notification, bool isSelectionMode) {
    if (isSelectionMode) return false;

    // 1. Reset on idle so tiny micro-scrolls don't stack up indefinitely over time
    if (notification is UserScrollNotification &&
        notification.direction == ScrollDirection.idle) {
      _accumulatedDelta = 0.0;
      return true;
    }

    if (notification is ScrollUpdateNotification) {
      // 2. TOP SNAP: Always expand when hitting the top (a highly satisfying native UX standard)
      if (notification.metrics.pixels <= HomeConstants.homeTopSnapThreshold) {
        updateFabState(extend: true);
        _accumulatedDelta = 0.0;
        return true;
      }

      // Ignore bounce/overscroll physics at the absolute edges of the list
      if (notification.metrics.outOfRange) return false;

      final double delta = notification.scrollDelta ?? 0.0;

      // 3. INTENT RESET: If the user changes finger direction, instantly clear the buffer.
      // This makes the button feel magnetically attached to their immediate intent.
      if ((delta > 0 && _accumulatedDelta < 0) ||
          (delta < 0 && _accumulatedDelta > 0)) {
        _accumulatedDelta = 0.0;
      }

      _accumulatedDelta += delta;

      // 4. THE PREMIUM THRESHOLD: Snappy but avoids jitter
      const double threshold = HomeConstants.homeBulkDeleteThreshold;

      if (_accumulatedDelta > threshold) {
        // Scrolling down -> Collapse
        updateFabState(extend: false);
        _accumulatedDelta = 0.0;
      } else if (_accumulatedDelta < -threshold) {
        // Scrolling up -> Expand
        updateFabState(extend: true);
        _accumulatedDelta = 0.0;
      }
    }

    return true;
  }

  // ==========================================
  // 8. CLOUD & BACKUP OPERATIONS
  // ==========================================

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
