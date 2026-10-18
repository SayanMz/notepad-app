import 'dart:typed_data';

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

  test('AppSettings copyWith preserves or updates userAvatarBytes', () {
    final avatarBytes = Uint8List.fromList([1, 2, 3, 4]);
    final settings = AppSettings(userAvatarBytes: avatarBytes);

    expect(settings.userAvatarBytes, equals(avatarBytes));

    final cleared = settings.copyWith(clearUser: true);
    expect(cleared.userAvatarBytes, isNull);
  });

  test('NotesSection toJson and fromJson preserve scrollOffset', () {
    final note = NotesSection(
      id: 'scroll-note-1',
      title: 'Scroll Title',
      content: 'Scroll Content',
      updatedAt: DateTime(2026, 1, 1),
    )..scrollOffset = 150.5;

    final json = note.toJson();
    expect(json['scrollOffset'], equals(150.5));

    final restored = NotesSection.fromJson(json);
    expect(restored.scrollOffset, equals(150.5));
  });
}
