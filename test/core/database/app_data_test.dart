import 'package:flutter_test/flutter_test.dart';
import 'package:notepad/core/database/app_data.dart';

void main() {
  test('NotesSection falls back to a default title and preview lines', () {
    final note = NotesSection(
      title: '   ',
      content: 'First line\nSecond line',
      updatedAt: DateTime(2024, 1, 1),
    );

    expect(note.displayTitle, 'Untitled Note');
    expect(note.getPreview(1), hasLength(1));
    expect(note.getPreview(1).first.text, 'First line');
  });

  test(
    'AppSettings copyWith can clear user data without changing other fields',
    () {
      final settings = AppSettings(
        isDarkMode: true,
        userName: 'Sayan',
        userEmail: 'sayan@example.com',
        seedVersion: 4,
        lastMaintenanceDate: DateTime(2024, 1, 5),
        recentColorValues: [1, 2, 3],
      );

      final updated = settings.copyWith(clearUser: true, isDarkMode: false);

      expect(updated.isDarkMode, isFalse);
      expect(updated.userName, isNull);
      expect(updated.userEmail, isNull);
      expect(updated.seedVersion, 4);
      expect(updated.recentColorValues, [1, 2, 3]);
      expect(updated.lastMaintenanceDate, DateTime(2024, 1, 5));
    },
  );
}
