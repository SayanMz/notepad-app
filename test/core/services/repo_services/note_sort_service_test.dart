import 'package:flutter_test/flutter_test.dart';
import 'package:notepad/core/database/app_data.dart';
import 'package:notepad/core/services/repo_services/note_sort_service.dart';

NotesSection _note(
  String id, {
  required bool pinned,
  required int positionIndex,
  required DateTime updatedAt,
}) {
  return NotesSection(
    id: id,
    title: id,
    content: id,
    isPinned: pinned,
    positionIndex: positionIndex,
    createdAt: updatedAt,
    updatedAt: updatedAt,
  );
}

void main() {
  test('sortActiveNotes keeps pinned notes first and orders by position', () {
    final notes = [
      _note(
        'unpinned-2',
        pinned: false,
        positionIndex: 2,
        updatedAt: DateTime(2024, 1, 1, 9),
      ),
      _note(
        'pinned-1',
        pinned: true,
        positionIndex: 1,
        updatedAt: DateTime(2024, 1, 1, 11),
      ),
      _note(
        'unpinned-0',
        pinned: false,
        positionIndex: 0,
        updatedAt: DateTime(2024, 1, 1, 12),
      ),
      _note(
        'pinned-0',
        pinned: true,
        positionIndex: 0,
        updatedAt: DateTime(2024, 1, 1, 10),
      ),
    ];

    NoteSortService.sortActiveNotes(notes);

    expect(notes.map((note) => note.id), [
      'pinned-0',
      'pinned-1',
      'unpinned-0',
      'unpinned-2',
    ]);
  });

  test('sortDeletedNotes keeps the most recently updated note first', () {
    final notes = [
      _note(
        'older',
        pinned: false,
        positionIndex: 0,
        updatedAt: DateTime(2024, 1, 1, 9),
      ),
      _note(
        'newer',
        pinned: false,
        positionIndex: 0,
        updatedAt: DateTime(2024, 1, 1, 12),
      ),
    ];

    NoteSortService.sortDeletedNotes(notes);

    expect(notes.map((note) => note.id), ['newer', 'older']);
  });

  test('insertSorted places a note ahead of later notes in the same zone', () {
    final notes = [
      _note(
        'first',
        pinned: false,
        positionIndex: 1,
        updatedAt: DateTime(2024, 1, 1, 10),
      ),
      _note(
        'third',
        pinned: false,
        positionIndex: 3,
        updatedAt: DateTime(2024, 1, 1, 10),
      ),
    ];

    final inserted = _note(
      'second',
      pinned: false,
      positionIndex: 2,
      updatedAt: DateTime(2024, 1, 1, 11),
    );
    final index = NoteSortService.insertSorted(notes, inserted);

    expect(index, 1);
    expect(notes.map((note) => note.id), ['first', 'second', 'third']);
  });

  test('reorderZone updates the moved zone and returned bulk map', () {
    final pinned = _note(
      'p1',
      pinned: true,
      positionIndex: 0,
      updatedAt: DateTime(2024, 1, 1, 10),
    );
    final first = _note(
      'u1',
      pinned: false,
      positionIndex: 2,
      updatedAt: DateTime(2024, 1, 1, 10),
    );
    final second = _note(
      'u2',
      pinned: false,
      positionIndex: 3,
      updatedAt: DateTime(2024, 1, 1, 11),
    );
    final activeNotes = [pinned, first, second];
    final zone = [first, second];

    final updates = NoteSortService.reorderZone(
      activeNotes: activeNotes,
      zoneList: zone,
      oldIndex: 0,
      newIndex: 1,
      isPinnedZone: false,
      pinnedCount: 1,
    );

    expect(zone.map((note) => note.id), ['u2', 'u1']);
    expect(zone.map((note) => note.positionIndex), [1, 2]);
    expect(updates.keys, {'u1', 'u2'});
  });
}
