import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:notepad/core/database/app_data.dart';
import 'package:notepad/core/database/notes_repository.dart';

// Recycle controller isolates deleted-note actions from the page widget.
class RecycleController extends ChangeNotifier {
  final NoteRepository noteRepository;

  RecycleController({required this.noteRepository}) {
    noteRepository.deletedRevision.addListener(_proxyListener);
  }

  void _proxyListener() {
    notifyListeners();
  }

  @override
  void dispose() {
    noteRepository.deletedRevision.removeListener(_proxyListener);
    super.dispose();
  }

  List<NotesSection> get deletedNotes => noteRepository.deletedNotes;
  bool get isEmpty => deletedNotes.isEmpty;

  Future<bool> restoreNote(String noteId) async {
    return await noteRepository.toggleDeletedStatus(noteId, false);
  }

  Future<void> undoRestore(String noteId) async {
    await noteRepository.toggleDeletedStatus(noteId, true);
  }

  Future<void> deleteForever(String noteId) async {
    await noteRepository.deleteForever(noteId);
  }

  Future<void> emptyRecycleBin() async {
    final Set<String> idsToDelete = deletedNotes.map((n) => n.id).toSet();

    await noteRepository.deleteForeverBulk(idsToDelete);
  }
}
