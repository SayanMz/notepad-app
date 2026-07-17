import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notepad/core/database/app_data.dart';
import 'package:notepad/core/database/notes_repository.dart';
import 'package:notepad/features/note/controllers/note_data_controller.dart';

class FakeNoteRepository extends NoteRepository {
  FakeNoteRepository() : super.internalForTesting();

  int saveCalls = 0;
  int deleteCalls = 0;
  String? lastSavedTitle;
  String? lastSavedContent;
  String? lastDeletedId;

  @override
  Future<NotesSection?> saveNote({
    required String? noteId,
    required String title,
    required String content,
    String richContent = '',
    bool notify = false,
    double scrollOffset = 0.0,
  }) async {
    saveCalls++;
    lastSavedTitle = title;
    lastSavedContent = content;

    return NotesSection(
      id: noteId ?? 'saved-note',
      title: title,
      content: content,
      richContent: richContent,
      createdAt: DateTime(2024, 1, 1),
      updatedAt: DateTime(2024, 1, 1),
    );
  }

  @override
  Future<void> deleteForever(String noteId) async {
    deleteCalls++;
    lastDeletedId = noteId;
  }
}

void main() {
  test(
    'saveAndCleanupOnClose deletes empty drafts instead of saving',
    () async {
      final repository = FakeNoteRepository();
      final controller = NoteDataController(
        noteRepository: repository,
        noteId: 'draft-1',
      );

      await controller.saveAndCleanupOnClose(
        title: '   ',
        document: Document(),
        scrollOffset: 0,
      );

      expect(repository.deleteCalls, 1);
      expect(repository.lastDeletedId, 'draft-1');
      expect(repository.saveCalls, 0);
    },
  );

  test(
    'saveNote persists non-empty editor content and stores the new note id',
    () async {
      final repository = FakeNoteRepository();
      final controller = NoteDataController(noteRepository: repository);
      final document = Document()..insert(0, 'Hello world');

      await controller.saveNote(title: '', document: document, notify: true);

      expect(repository.saveCalls, 1);
      expect(repository.lastSavedTitle, 'Untitled note');
      expect(repository.lastSavedContent, 'Hello world');
      expect(controller.noteId, 'saved-note');
    },
  );
}
