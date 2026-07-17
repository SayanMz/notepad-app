import 'package:notepad/core/database/app_data.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notepad/features/home/controllers/selection_controller.dart';

void main() {
  List<String> noteIds() => ['a', 'b', 'c'];

  test('toggleSelected updates selection count and mode', () {
    final controller = SelectionController();

    controller.toggleSelected('a');
    expect(controller.isSelectionMode, isTrue);
    expect(controller.hasSelection, isTrue);
    expect(controller.selectionCount, 1);
    expect(controller.isNoteSelected('a'), isTrue);

    controller.toggleSelected('a');
    expect(controller.isSelectionMode, isFalse);
    expect(controller.hasSelection, isFalse);
    expect(controller.selectionCount, 0);
  });

  test(
    'setSelectAll selects every active note and exitSelectionMode clears it',
    () {
      final controller = SelectionController();

      controller.setSelectAll(noteIds().map((id) => _note(id)).toList(), true);
      expect(
        controller.areAllSelected(noteIds().map((id) => _note(id)).toList()),
        isTrue,
      );
      expect(controller.selectionCount, 3);

      controller.exitSelectionMode();
      expect(controller.isSelectionMode, isFalse);
      expect(controller.selectedIds, isEmpty);
    },
  );

  test('removeIds clears the remaining selection and exits selection mode', () {
    final controller = SelectionController();

    controller.setSelectAll(noteIds().map((id) => _note(id)).toList(), true);
    controller.removeIds(['a', 'b', 'c']);

    expect(controller.selectedIds, isEmpty);
    expect(controller.isSelectionMode, isFalse);
  });
}

NotesSection _note(String id) {
  return NotesSection(
    id: id,
    title: id,
    content: id,
    createdAt: DateTime(2024, 1, 1),
    updatedAt: DateTime(2024, 1, 1),
  );
}
