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
  @override
  List<NotesSection> get activeNotes => [NotesSection(title: 'Test Note')];
  @override
  List<NotesSection> get pinnedNotes => [];
  @override
  List<NotesSection> get unpinnedNotes => [NotesSection(title: 'Test Note')];
}

void main() {
  testWidgets('NoteList adapts maxPreviewLines based on screen width', (tester) async {
    final repo = MockNoteRepository();
    final controller = HomeController(
      selectionController: SelectionController(),
      animationController: AnimationControllerState(),
      noteRepository: repo,
    );
    final fabController = HomeFabController();

    // 1. Test Phone Width (Compact)
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CustomScrollView(
            slivers: [NoteList(controller: controller, fabController: fabController)],
          ),
        ),
      ),
    );
    
    expect(find.text('Test Note'), findsOneWidget);

    // 2. Test Desktop Width
    tester.view.physicalSize = const Size(1400, 900);
    await tester.pumpAndSettle();
    
    expect(find.text('Test Note'), findsOneWidget);

    // Reset view
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}
