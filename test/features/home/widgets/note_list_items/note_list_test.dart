import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notepad/core/database/app_data.dart';
import 'package:notepad/core/database/notes_repository.dart';
import 'package:notepad/features/home/controllers/animation_controller.dart';
import 'package:notepad/features/home/controllers/home_controller.dart';
import 'package:notepad/features/home/controllers/home_fab_controller.dart';
import 'package:notepad/features/home/controllers/selection_controller.dart';
import 'package:notepad/features/home/widgets/note_list_items/note_list.dart';

class MockNoteRepository extends NoteRepository {
  MockNoteRepository() : super.internalForTesting();

  List<NotesSection> mockActive = [];
  List<NotesSection> mockPinned = [];
  List<NotesSection> mockUnpinned = [];

  @override
  List<NotesSection> get activeNotes => mockActive;
  @override
  List<NotesSection> get pinnedNotes => mockPinned;
  @override
  List<NotesSection> get unpinnedNotes => mockUnpinned;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('NoteList displays pinned and unpinned sections', (tester) async {
    final repo = MockNoteRepository();
    final controller = HomeController(
      selectionController: SelectionController(),
      animationController: AnimationControllerState(),
      noteRepository: repo,
    );
    final fabController = HomeFabController();

    final pinnedNote = NotesSection(id: '1', title: 'Pinned Note', isPinned: true);
    final unpinnedNote = NotesSection(id: '2', title: 'Other Note', isPinned: false);
    
    repo.mockActive = [pinnedNote, unpinnedNote];
    repo.mockPinned = [pinnedNote];
    repo.mockUnpinned = [unpinnedNote];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CustomScrollView(
            slivers: [
              NoteList(
                controller: controller,
                fabController: fabController,
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.textContaining('PINNED (1)'), findsOneWidget);
    expect(find.textContaining('OTHERS (1)'), findsOneWidget);
    expect(find.text('Pinned Note'), findsOneWidget);
    expect(find.text('Other Note'), findsOneWidget);
  });
}
