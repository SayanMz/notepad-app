import 'package:flutter/material.dart';
import 'package:notepad/core/constants/ui_constants.dart';
import 'package:notepad/core/data/app_data.dart';
import 'package:notepad/features/home/services/google_drive_service.dart';
import 'package:notepad/features/note/data/note_repository.dart';
import 'package:notepad/core/services/ui_notifier.dart';
import 'package:notepad/features/note/services/note_document_service.dart';
import 'package:notepad/features/home/services/app_router.dart';
import 'package:notepad/features/note/note_page.dart';

/// ---------------------------------------------------------------------------
/// HOME CONTROLLER (BUSINESS LOGIC LAYER)
/// ---------------------------------------------------------------------------
///
/// ROLE IN ARCHITECTURE:
/// - Acts as the intermediary between UI (HomePage) and data/services
/// - Encapsulates business logic to keep UI clean and declarative
///
/// RESPONSIBILITIES:
/// - Expose derived state from repository
/// - Handle note actions (open, pin, delete, share)
/// - Manage side effects (navigation, SnackBars, persistence)
///
/// DESIGN PRINCIPLES:
/// - Thin controller (not bloated with UI logic)
/// - Repository remains the single source of truth
/// - UI delegates actions ÃƒÂ¢Ã¢â‚¬Â Ã¢â‚¬â„¢ controller executes
///

class HomeController {
  // -------------------------------------------------------------------------
  // STATE HELPERS (DERIVED STATE)
  // -------------------------------------------------------------------------

  /// Whether selection mode is active.
  ///
  /// NOTE:
  /// - Derived from repository (not stored locally)
  /// - Prevents duplication of state in UI
  bool get isSelectionMode => noteRepository.selectedNotes.isNotEmpty;

  /// Active notes currently visible to user.
  ///
  /// SOURCE:
  /// - Directly from repository
  /// - Always up-to-date via ListenableBuilder
  List<NotesSection> get activeNotes => noteRepository.activeNotes;

  /// Whether all active notes are selected.
  ///
  /// Used for:
  /// - "Select All" checkbox state
  bool get allSelected => noteRepository.areAllActiveNotesSelected;

  // -------------------------------------------------------------------------
  // ACTIONS (USER INTENTS)
  // -------------------------------------------------------------------------

  /// Opens a note page.
  ///
  /// SIDE EFFECTS:
  /// - Clears existing SnackBars for clean UX
  /// - Navigates using centralized AppRouter
  Future<void> openNote(BuildContext context, {String? noteId}) async {
    uiNotifier.clearSnackBars();

    await Navigator.push(context, AppRouter.slide(NotePage(noteId: noteId)));
  }

  /// Toggles pin state of a note.
  ///
  /// DESIGN:
  /// - Immediate mutation + persistence
  /// - Keeps UI responsive and consistent
  Future<void> togglePin(String noteId) async {
    noteRepository.togglePin(noteId);
  }

  /// Shares selected notes as HTML.
  ///
  /// UX:
  /// - Gracefully handles empty selection
  /// - Shows error feedback via SnackBar
  Future<void> shareSelectedNotes(BuildContext context) async {
    final selectedNotes = noteRepository.selectedNotes;

    if (selectedNotes.isEmpty) return;

    try {
      await NoteDocumentService.shareNotesAsHTML(
        selectedNotes,
        text: 'Sharing ${selectedNotes.length} Notes',
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not share selected notes: $e')),
      );
    }
  }

  /// Deletes selected notes (moves to recycle bin).
  ///
  /// UX PATTERN:
  /// - Performs soft delete (recoverable)
  /// - Shows Snackbar with restore option
  Future<void> deleteSelected(List<NotesSection> notes) async {
    final selectedNotes = notes;
    final selectedCount = selectedNotes.length;

    if (selectedCount == 0) return;

    /// Store IDs for undo functionality
    final movedNoteIds = selectedNotes.map((n) => n.id).toList();

    /// Perform deletion
    noteRepository.moveSelectedNotesToRecycleBin(selectedNotes);

    /// Undo Snackbar
    uiNotifier.showSnackBar(
      SnackBar(
        key: UniqueKey(),
        duration: UIConstants.saveIndicatorDuration,
        content: Text(
          '$selectedCount ${selectedCount == 1 ? 'note' : 'notes'} moved to recycle bin',
        ),
        action: SnackBarAction(
          label: 'Restore',
          onPressed: () async {
            uiNotifier.hideCurrentSnackBar();

            for (final id in movedNoteIds) {
              noteRepository.restoreNote(id);
            }
          },
        ),
      ),
      autoHideAfter: UIConstants.saveIndicatorDuration,
    );
  }

  /// Toggles selection mode.
  ///
  /// BEHAVIOR:
  /// - Disabling selection clears all selected notes
  /// - Keeps repository as single source of truth
  void toggleSelectionMode(bool enabled) {
    if (!enabled) {
      noteRepository.clearSelection();
    }
  }

  /// Initiates a standard, sequential backup[cite: 1, 10]
  ///
  /// This method awaits the result to ensure your UI's loading spinner[cite: 10]
  /// stays active for the entire duration of the actual network work[cite: 11].
  Future<void> runManualBackup() async {
    try {
      // 1. Fetch current data from your local system[cite: 11]
      final jsonString = await noteRepository.exportNotesToBackupString();

      // 2. Pass it to the service for upload[cite: 1]
      // The service handles the JSON-to-byte conversion and Drive I/O[cite: 11].
      await googleDriveService.uploadBackup(jsonString);

      debugPrint("Manual backup completed successfully.");
    } catch (e) {
      debugPrint("Error during manual backup: $e");
      // [cite: Stage 9 Optimization]: In a robust design, you would pass this error[cite: 10]
      // to the UI to show a 'Backup Failed' snackbar, rather than just printing.
      rethrow; // Pass error up so onTap can handle UI cleanup if needed[cite: 10]
    }
  }

  /// Initiates a sequential restore, replacing local data
  ///
  /// This method awaits the download and import process sequentially[cite: 1, 10].
  /// It ensures that `false` isn't triggered on your spinner[cite: 10] until the
  /// data is fully merged into your app's memory[cite: 10, 11].
  Future<void> runManualRestore() async {
    try {
      // 1. PASSIVE WAIT (Download): Wait for the data to arrive[cite: 1, 10]
      // We expect either the full JSON backup string or null (if no backup exists)[cite: 1].
      final backupJson = await googleDriveService.downloadBackup();

      if (backupJson == null || backupJson.isEmpty) {
        debugPrint("No valid backup found on Google Drive.");
        // You should handle this in the UI, perhaps with a 'No Backup Found' dialog.
        return;
      }

      // 2. ACTIVE WORK (Import): We now have the data, proceed with merge[cite: 11, 12]
      // This is the active computation phase. noteRepository will decode,
      // clear local memory, and merge the new data[cite: 11].
      await noteRepository.importNotesFromBackupString(backupJson);

      // 3. COMPLETE: The sequential flow is finished[cite: 10, 12]
      debugPrint("Manual restore and data merge completed successfully.");
    } catch (e) {
      debugPrint("Error during manual restore: $e");
      // Handle error communication to UI here or rethrow[cite: 10].
      rethrow;
    }
  }
}
