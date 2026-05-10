import 'package:flutter/material.dart';
import 'package:notepad/core/constants/ui_constants.dart';
import 'package:notepad/core/data/app_data.dart';
import 'package:notepad/core/services/scaffold_messenger_notifier.dart';
import 'package:notepad/features/home/services/google_drive_service.dart';
import 'package:notepad/core/data/notes_repository.dart';
import 'package:notepad/features/note/services/note_document_service.dart';
import 'package:notepad/features/home/services/app_router.dart';
import 'package:notepad/features/note/note_page.dart';

class HomeController {
  List<NotesSection> get activeNotes => noteRepository.activeNotes;
  List<NotesSection> get selectedNotes => noteRepository.selectedNotes;

  bool get isSelectionMode => selectedNotes.isNotEmpty;
  bool get allSelected => noteRepository.areAllActiveNotesSelected;
  // If at least one selected note is NOT pinned, we show the 'Pin' action
  bool get showPinAction => selectedNotes.any((n) => !n.isPinned);

  Future<void> openNote(BuildContext context, {String? noteId}) async {
    uiNotifier.clearSnackBars();
    await Navigator.push(context, AppRouter.slide(NotePage(noteId: noteId)));
  }

  Future<void> togglePin(String noteId) async {
    await noteRepository.togglePinStatus(noteId);
  }

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
      showErrorSnackBar('Could not share selected notes: $e');
    }
  }

  Future<void> togglePinBulk() async {
    noteRepository.togglePinBulk(showPinAction);
  }

  Future<void> deleteSelected(List<NotesSection> notes) async {
    if (notes.isEmpty) return;

    final movedNoteIds = notes.map((n) => n.id).toList();
    noteRepository.toggleDeletedStatusBulk(movedNoteIds, true);

    uiNotifier.showSnackBar(
      SnackBar(
        key: UniqueKey(),
        duration: UIConstants.saveIndicatorDuration,
        content: Text(
          '${notes.length} ${notes.length == 1 ? 'note' : 'notes'} moved to recycle bin',
        ),
        action: SnackBarAction(
          label: 'Restore',
          onPressed: () async {
            uiNotifier.hideCurrentSnackBar();
            for (final id in movedNoteIds) {
              noteRepository.toggleDeletedStatus(id, false);
            }
          },
        ),
      ),
      autoHideAfter: UIConstants.saveIndicatorDuration,
    );
  }

  // void toggleSelectionMode(bool enabled) {
  //   if (!enabled) {
  //     noteRepository.clearSelection();
  //   }
  // }

  Future<void> runManualBackup() async {
    try {
      final jsonString = await noteRepository.exportNotesToBackupString();
      await googleDriveService.uploadBackup(jsonString);
      debugPrint('Manual backup completed successfully.');
    } catch (e) {
      debugPrint('Error during manual backup: $e');
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
      debugPrint('Error during manual restore: $e');
      rethrow;
    }
  }
}
