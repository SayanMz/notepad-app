import 'package:flutter_test/flutter_test.dart';
import 'package:notepad/core/database/app_data.dart';
import 'package:notepad/core/database/notes_repository.dart';
import 'package:notepad/features/trash/controller/recycle_controller.dart';

class FakeRecycleRepository extends NoteRepository {
  FakeRecycleRepository() : super.internalForTesting();

  final List<NotesSection> backingDeleted = [];
  String? restoredId;
  String? undoneId;
  String? deletedForeverId;
  Set<String>? emptiedIds;

  @override
  List<NotesSection> get deletedNotes => backingDeleted;

  @override
  Future<bool> toggleDeletedStatus(String noteId, bool isDeleted) async {
    restoredId = isDeleted ? null : noteId;
    undoneId = isDeleted ? noteId : null;
    deletedRevision.value++;
    return true;
  }

  @override
  Future<void> deleteForever(String noteId) async {
    deletedForeverId = noteId;
    deletedRevision.value++;
  }

  @override
  Future<void> deleteForeverBulk(Set<String> noteIds) async {
    emptiedIds = noteIds;
    backingDeleted.removeWhere((note) => noteIds.contains(note.id));
    deletedRevision.value++;
  }
}

NotesSection _note(String id) {
  return NotesSection(
    id: id,
    title: id,
    content: id,
    isDeleted: true,
    createdAt: DateTime(2024, 1, 1),
    updatedAt: DateTime(2024, 1, 1),
  );
}

void main() {
  test('RecycleController mirrors repository updates and delegates actions', () async {
    final repo = FakeRecycleRepository()
      ..backingDeleted.addAll([_note('one'), _note('two')]);
    final controller = RecycleController(noteRepository: repo);
    var notifications = 0;
    controller.addListener(() => notifications++);

    expect(controller.isEmpty, isFalse);

    await controller.restoreNote('one');
    expect(repo.restoredId, 'one');

    await controller.undoRestore('one');
    expect(repo.undoneId, 'one');

    await controller.deleteForever('two');
    expect(repo.deletedForeverId, 'two');

    await controller.emptyRecycleBin();
    expect(repo.emptiedIds, {'one', 'two'});

    repo.deletedRevision.value++;
    expect(notifications, greaterThan(0));

    controller.dispose();
  });
}
