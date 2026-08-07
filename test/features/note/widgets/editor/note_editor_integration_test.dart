import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notepad/core/database/app_data.dart';
import 'package:notepad/core/database/notes_repository.dart';
import 'package:notepad/features/note/controllers/note_data_controller.dart';
import 'package:notepad/features/note/widgets/editor/note_editor.dart';
import 'package:notepad/features/note/widgets/status/save_indicator.dart';

class FakeNoteRepository extends NoteRepository {
  FakeNoteRepository() : super.internalForTesting();
  int saveCount = 0;

  @override
  Future<NotesSection?> saveNote({
    required String? noteId,
    required String title,
    required String content,
    String richContent = '',
    bool notify = false,
    double scrollOffset = 0.0,
  }) async {
    saveCount++;
    return NotesSection(title: title, id: 'saved-1');
  }
  
  @override
  NotesSection? findById(String id) => null;
}

void main() {
  testWidgets('Typing in editor triggers autosave after debounce', (tester) async {
    final repository = FakeNoteRepository();
    final dataController = NoteDataController(noteRepository: repository);
    final quillController = QuillController.basic();
    final focusNode = FocusNode();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              SaveIndicator(saveState: dataController.saveState),
              Expanded(
                child: NoteEditor(
                  controller: quillController,
                  focusNode: focusNode,
                  scrollController: ScrollController(),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    // 1. Initial state
    expect(find.text('Changes saved'), findsNothing);

    // 2. Simulate typing
    quillController.document.insert(0, 'Typing test');
    dataController.handleEditorChanged(
      title: 'Title',
      document: quillController.document,
      controller: quillController,
      change: null,
    );

    // 3. Trigger the debounce (3 seconds in production)
    await tester.pump(const Duration(seconds: 4));
    
    // Repository should have been called once
    expect(repository.saveCount, 1);

    // 4. Wait for the "Saved" status feedback timers to finish (0.5s + 3s)
    await tester.pump(const Duration(seconds: 5));
    
    dataController.dispose();
  });
}
