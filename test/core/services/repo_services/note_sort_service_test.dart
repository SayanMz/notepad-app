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

  test('sortDeletedNotes keeps the most recently created note first (by ID)', () {
    final notes = [
      _note(
        'id-1', // older
        pinned: false,
        positionIndex: 0,
        updatedAt: DateTime(2024, 1, 1, 9),
      ),
      _note(
        'id-2', // newer
        pinned: false,
        positionIndex: 0,
        updatedAt: DateTime(2024, 1, 1, 12),
      ),
    ];

    NoteSortService.sortDeletedNotes(notes);

    expect(notes.map((note) => note.id), ['id-2', 'id-1']);
  });

  test('insertSorted places a note ahead of later notes in the same zone', () {
    final notes = [
      _note(
        'id-1',
        pinned: false,
        positionIndex: 1,
        updatedAt: DateTime(2024, 1, 1, 10),
      ),
      _note(
        'id-3',
        pinned: false,
        positionIndex: 3,
        updatedAt: DateTime(2024, 1, 1, 10),
      ),
    ];

    final inserted = _note(
      'id-2',
      pinned: false,
      positionIndex: 2,
      updatedAt: DateTime(2024, 1, 1, 11),
    );
    final index = NoteSortService.insertSorted(notes, inserted);

    expect(index, 1);
    expect(notes.map((note) => note.id), ['id-1', 'id-2', 'id-3']);
  });

  test('insertSorted with atIndex bypasses search and inserts directly', () {
    final notes = [_note('a', pinned: false, positionIndex: 0, updatedAt: DateTime.now())];
    final note = _note('b', pinned: false, positionIndex: 5, updatedAt: DateTime.now());

    final index = NoteSortService.insertSorted(notes, note, atIndex: 0);

    expect(index, 0);
    expect(notes.first.id, 'b');
  });

  test('sortActiveNotes uses ULID as a final tie-break (Reverse Order)', () {
    // note_01h... is older than note_01j...
    final notes = [
      _note('note_01h123', pinned: true, positionIndex: 0, updatedAt: DateTime.now()),
      _note('note_01j456', pinned: true, positionIndex: 0, updatedAt: DateTime.now()),
    ];

    NoteSortService.sortActiveNotes(notes);

    // Newer ULID (01j) should be first
    expect(notes.map((n) => n.id), ['note_01j456', 'note_01h123']);
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
