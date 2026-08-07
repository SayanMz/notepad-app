import 'package:flutter_test/flutter_test.dart';
import 'package:notepad/core/database/app_data.dart';

void main() {
  test('generateNoteId returns note-prefixed unique identifiers', () {
    final first = generateNoteId();
    final second = generateNoteId();

    expect(first.startsWith('note_'), isTrue);
    expect(second.startsWith('note_'), isTrue);
    expect(first, isNot(equals(second)));
  });

  test('NotesSection.fromJson restores stored note metadata', () {
    final note = NotesSection.fromJson({
      'id': 'note_123',
      'title': 'Stored title',
      'content': 'Stored body',
      'richContent': '',
      'updatedAt': '2024-01-02T10:00:00.000',
      'isDeleted': true,
      'isPinned': true,
      'cardColorValue': 0xFF112233,
    });

    expect(note.id, 'note_123');
    expect(note.displayTitle, 'Stored title');
    expect(note.content, 'Stored body');
    expect(note.isDeleted, isTrue);
    expect(note.isPinned, isTrue);
    expect(note.cardColorValue, 0xFF112233);
  });
}
