import 'package:flutter_test/flutter_test.dart';
import 'package:notepad/core/database/app_data.dart';
import 'package:notepad/core/services/repo_services/backup_sync_service.dart';

void main() {
  test('calculateImportUpdates keeps only notes missing locally', () {
    final localDeleted = NotesSection(
      id: 'deleted',
      title: 'Deleted',
      content: 'Deleted',
      isDeleted: true,
      updatedAt: DateTime(2024, 1, 1),
    );

    NotesSection? localLookup(String id) {
      if (id == 'present') {
        return NotesSection(
          id: 'present',
          title: 'Present',
          content: 'Present',
          updatedAt: DateTime(2024, 1, 1),
        );
      }
      if (id == 'deleted') return localDeleted;
      return null;
    }

    final updates = BackupSyncService.calculateImportUpdates(
      cloudNotes: [
        NotesSection(
          id: 'present',
          title: 'Present',
          content: 'Cloud version',
          updatedAt: DateTime(2024, 1, 1),
        ),
        NotesSection(
          id: 'deleted',
          title: 'Deleted',
          content: 'Cloud version',
          updatedAt: DateTime(2024, 1, 1),
        ),
        NotesSection(
          id: 'new-note',
          title: 'New note',
          content: 'New content',
          updatedAt: DateTime(2024, 1, 1),
        ),
      ],
      localNoteLookup: localLookup,
    );

    expect(updates.updates.keys, {'new-note'});
    expect(updates.updates['new-note']?.title, 'New note');
    expect(updates.skippedCount, 2);
  });
}
