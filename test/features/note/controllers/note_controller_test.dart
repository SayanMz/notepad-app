import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_quill/flutter_quill.dart'; // Needed for Document
import 'package:notepad/core/data/app_data.dart'; // Needed for NotesSection
import 'package:notepad/features/note/controllers/note_controller.dart';
import 'package:notepad/features/note/data/note_repository.dart';
import 'package:notepad/features/note/services/note_recovery_service.dart';
import 'package:notepad/features/note/widgets/save_indicator.dart';

// -----------------------------------------------------------------------------
// 1. THE FAKES (Mocking the dependencies)
// -----------------------------------------------------------------------------

/// A fake repository that mimics your Hive database in memory
class FakeNoteRepository extends NoteRepository {
  // Override the singleton for testing to prevent Hive errors
  FakeNoteRepository() : super.internalForTesting();

  final List<NotesSection> savedNotes = [];
  int deleteCounter = 0;

  @override
  NotesSection? saveNote({
    required String? noteId,
    required String title,
    required String content,
    String richContent = '',
  }) {
    // Mimic the real repository logic: Create a new note and return it
    final newNote = NotesSection(
      id: noteId ?? 'fake_id_123',
      title: title,
      content: content,
      richContent: richContent,
    );
    savedNotes.add(newNote);
    return newNote;
  }

  @override
  bool deleteForever(String noteId) {
    deleteCounter++;
    return true;
  }
}

/// A fake recovery service that does nothing (keeps tests fast)
class FakeRecoveryService extends NoteRecoveryService {
  @override
  Future<void> saveShadowDraft(String key, List<String> draft) async {
    // Do nothing for the test
  }
}

// -----------------------------------------------------------------------------
// 2. THE TESTS
// -----------------------------------------------------------------------------

void main() {
  group('NoteController Core Logic', () {
    test('State changes instantly from idle -> saving -> saved', () async {
      // ARRANGE
      final fakeRepo = FakeNoteRepository();
      final fakeRecovery = FakeRecoveryService();

      final controller = NoteController(
        noteRepository: fakeRepo,
        recoveryService: fakeRecovery,
      );

      // Create a dummy Quill Document for testing
      final testDocument = Document()..insert(0, 'Hello World');

      expect(controller.saveState.value, SaveState.idle);

      // ACT
      // We don't await immediately, we capture the Future
      final saveProcess = controller.saveNote(
        title: "Test Note",
        document: testDocument,
      );

      // ASSERT 1: The exact millisecond it starts, it must be saving
      expect(controller.saveState.value, SaveState.saving);

      // Wait for the simulated delay in the controller to finish
      await saveProcess;

      // ASSERT 2: Once finished, it must be saved
      expect(controller.saveState.value, SaveState.saved);

      // Clean up
      controller.dispose();
    });

    test('saveAndCleanupOnClose deletes empty note and prevents save', () {
      // ARRANGE
      final fakeRepo = FakeNoteRepository();
      final fakeRecovery = FakeRecoveryService();

      final controller = NoteController(
        noteId: 'existing_empty_note_id', // Pretend we opened an empty note
        noteRepository: fakeRepo,
        recoveryService: fakeRecovery,
      );

      // Create a completely empty Document
      final emptyDocument = Document();

      // ACT: Simulate the user pressing the back button
      controller.saveAndCleanupOnClose(title: "", document: emptyDocument);

      // ASSERT
      // 1. It should have called deleteForever exactly once
      expect(fakeRepo.deleteCounter, 1);

      // 2. It should NOT have saved anything to the database
      expect(fakeRepo.savedNotes.length, 0);

      controller.dispose();
    });
  });
}
