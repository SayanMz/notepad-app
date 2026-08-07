import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notepad/core/database/app_data.dart';
import 'package:notepad/core/database/notes_repository.dart';
import 'package:notepad/features/trash/controller/recycle_controller.dart';
import 'package:notepad/features/trash/widgets/recycle_notes_sliver_list.dart';
import 'package:notepad/features/trash/widgets/swippeable_restore_item.dart';

class FakeRecycleRepository extends NoteRepository {
  FakeRecycleRepository() : super.internalForTesting();
  @override
  List<NotesSection> get deletedNotes => [
        NotesSection(id: '1', title: 'Deleted 1', isDeleted: true),
        NotesSection(id: '2', title: 'Deleted 2', isDeleted: true),
      ];
}

void main() {
  testWidgets('RecycleNotesSliverList renders info text and note items', (tester) async {
    final repo = FakeRecycleRepository();
    final controller = RecycleController(noteRepository: repo);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CustomScrollView(
            slivers: [
              RecycleNotesSliverList(
                controller: controller,
                cardWidth: 400,
                onRestore: (note) {},
                onShowActionSheet: (context, note) {},
              ),
            ],
          ),
        ),
      ),
    );

    // Verify info text
    expect(find.textContaining('permanently deleted after 30 days'), findsOneWidget);

    // Verify items
    expect(find.byType(SwipeableRestoreItem), findsNWidgets(2));
    expect(find.text('Deleted 1'), findsOneWidget);
    expect(find.text('Deleted 2'), findsOneWidget);
  });
}
