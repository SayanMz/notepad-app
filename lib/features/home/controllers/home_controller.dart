import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:notepad/core/constants/animation_constants.dart';
import 'package:notepad/core/data/app_data.dart';
import 'package:notepad/core/data/notes_repository.dart';
import 'package:notepad/core/services/scaffold_messenger_notifier.dart';
import 'package:notepad/features/home/controllers/animation_controller.dart';
import 'package:notepad/features/home/controllers/selection_controller.dart';
import 'package:notepad/features/home/home_constants.dart';
import 'package:notepad/features/home/services/auth_controller.dart';
import 'package:notepad/features/home/services/google_drive_service.dart';
import 'package:notepad/features/note/services/note_document_service.dart';

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
  // 🌟 SIDE-CHANNEL: Doesn't trigger notifyListeners()
  final ValueNotifier<int> colorChangeNotifier = ValueNotifier<int>(0);

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

  // If at least one selected note is NOT pinned, we show the 'Pin' action
  bool get showPinAction => selectedNotes.any((n) => !n.isPinned);

  List<NotesSection> get pinnedNotes => noteRepository.pinnedNotes;
  List<NotesSection> get unpinnedNotes => noteRepository.unpinnedNotes;
  bool get hasActiveNotes => noteRepository.activeNotes.isNotEmpty;
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
    }
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
    notifyListeners(); // Triggers the HomeFab to hide/show smoothly
  }

  // Combined Deletion Execution Flow leveraging SelectionController
  Future<void> executeBulkDelete() async {
    if (selectionController.selectedIds.isEmpty) return;

    // 1. Fetch data directly via your Sub-Controller
    final movedNoteIds = selectionController.selectedIds.toSet();
    final int selectedCount = movedNoteIds.length;

    // 2. Execute transactional backend repository mutation
    await animationController.triggerVaporizeAnimation(movedNoteIds);
    await noteRepository.toggleDeletedStatusBulk(movedNoteIds, true);

    // 3. Clear the selection manager state instantly to reset overlays
    selectionController.exitSelectionMode();
    HapticFeedback.heavyImpact(); // Premium tactical physical feedback

    // 4. Render the restoration Snackbar setup
    showRestorationSnackBar(
      undoLabel: 'Restore',
      message:
          '$selectedCount ${selectedCount == 1 ? 'note' : 'notes'} moved to recycle bin',
      onUndo: () async {
        // 🌟 RESTORE THE TRACKED NOTE IDS BACK INTO ACTIVE VIEWS
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
  void updateFabState({required bool extend}) {
    if (isFabExtended.value == extend) return;
    isFabExtended.value = extend;
    fabAlignX.value = extend
        ? HomeConstants.fabAlignExpandedX
        : HomeConstants.fabAlignCollapsedX;
  }

  /// Handle database state preservation during reordering events
  void handlePinnedReorder(int oldIndex, int newIndex) {
    noteRepository.reorderPinnedNotes(oldIndex, newIndex);
  }

  void handleUnpinnedReorder(int oldIndex, int newIndex) {
    noteRepository.reorderUnpinnedNotes(oldIndex, newIndex);
  }

  /// Instant transactional execution for toggling pins
  void handleTogglePin(String id) {
    noteRepository.togglePinStatus(id);
  }

  // SCROLL LOGIC
  bool handleFabScroll(Notification notification) {
    if (selectionController.isSelectionMode) return false;

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
