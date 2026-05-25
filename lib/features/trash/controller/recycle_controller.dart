import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:notepad/core/data/app_data.dart';
import 'package:notepad/core/data/notes_repository.dart';

class RecycleController extends ChangeNotifier {
  final NoteRepository noteRepository;

  RecycleController({required this.noteRepository}) {
    // Forward repository updates to the UI
    noteRepository.deletedRevision.addListener(_proxyListener);
  }

  void _proxyListener() {
    // Any change in the repo triggers a rebuild for whoever is listening to this controller
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
