import 'package:flutter_test/flutter_test.dart';
import 'package:notepad/core/database/app_data.dart';

void main() {
  group('NotesSection Expiry Logic', () {
    test('isExpired returns true after 30 days', () {
      final oldNote = NotesSection(
        title: 'Old Note',
        updatedAt: DateTime.now().subtract(const Duration(days: 31)),
      );

      final freshNote = NotesSection(
        title: 'Fresh Note',
        updatedAt: DateTime.now().subtract(const Duration(days: 10)),
      );

      expect(oldNote.isExpired, isTrue);
      expect(freshNote.isExpired, isFalse);
    });

    test('daysLeft calculates the remaining time correctly', () {
      final note = NotesSection(
        title: 'Expiring Note',
        updatedAt: DateTime.now().subtract(const Duration(days: 20)),
      );

      // 30 - 20 = 10
      expect(note.daysLeft, 10);
    });

    test('daysLeft returns 0 or negative for expired notes', () {
      final note = NotesSection(
        title: 'Expired Note',
        updatedAt: DateTime.now().subtract(const Duration(days: 35)),
      );

      expect(note.daysLeft, lessThanOrEqualTo(0));
    });
  });
}
