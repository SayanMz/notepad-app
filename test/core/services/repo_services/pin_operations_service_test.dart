import 'package:flutter_test/flutter_test.dart';
import 'package:notepad/core/database/app_data.dart';
import 'package:notepad/core/services/repo_services/pin_operations_service.dart';

NotesSection _note(
  String id, {
  required bool pinned,
  required int positionIndex,
}) {
  return NotesSection(
    id: id,
    title: id,
    content: id,
    isPinned: pinned,
    positionIndex: positionIndex,
    updatedAt: DateTime(2024, 1, 1),
  );
}

void main() {
  test('togglePinState flips pinned status and refreshes updatedAt', () {
    final note = _note('note-1', pinned: false, positionIndex: 1);
    final toggled = PinOperationsService.togglePinState(note);

    expect(toggled.isPinned, isTrue);
    expect(toggled.updatedAt.isAfter(DateTime(2024, 1, 1)), isTrue);
  });

  test('processBulkPin assigns contiguous positions for pinned notes', () {
    final activeNotes = [
      _note('a', pinned: false, positionIndex: 0),
      _note('b', pinned: false, positionIndex: 1),
      _note('c', pinned: false, positionIndex: 2),
    ];

    final updates = PinOperationsService.processBulkPin(
      activeNotes: activeNotes,
      targetIds: {'b', 'c'},
      goalState: true,
      currentPinnedCount: 1,
    );

    expect(updates.keys, {'b', 'c'});
    expect(activeNotes[1].isPinned, isTrue);
    expect(activeNotes[2].isPinned, isTrue);
    expect(activeNotes[1].positionIndex, 1);
    expect(activeNotes[2].positionIndex, 2);
  });

  test('processBulkPin handles unpinning with negative indices', () {
    final activeNotes = [
      _note('a', pinned: true, positionIndex: 0),
      _note('b', pinned: true, positionIndex: 1),
    ];

    final updates = PinOperationsService.processBulkPin(
      activeNotes: activeNotes,
      targetIds: {'a', 'b'},
      goalState: false,
      currentPinnedCount: 2,
    );

    expect(updates.length, 2);
    expect(activeNotes[0].isPinned, isFalse);
    expect(activeNotes[1].isPinned, isFalse);
    // Counter starts at -2
    expect(activeNotes[0].positionIndex, -2);
    expect(activeNotes[1].positionIndex, -1);
  });
}
