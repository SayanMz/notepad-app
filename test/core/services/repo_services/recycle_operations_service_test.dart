import 'package:flutter_test/flutter_test.dart';
import 'package:notepad/core/database/app_data.dart';
import 'package:notepad/core/services/repo_services/recycle_operations_service.dart';

void main() {
  group('RecycleOperationsService', () {
    test('processBulkMove moves notes from active to deleted', () {
      final note1 = NotesSection(id: '1', title: 'Note 1', isDeleted: false);
      final note2 = NotesSection(id: '2', title: 'Note 2', isDeleted: false);
      final activeNotes = [note1, note2];
      final deletedNotes = <NotesSection>[];

      final result = RecycleOperationsService.processBulkMove(
        currentActive: activeNotes,
        currentDeleted: deletedNotes,
        targetIds: {'1'},
        toDelete: true,
      );

      expect(activeNotes, [note2]);
      expect(deletedNotes, [note1]);
      expect(note1.isDeleted, isTrue);
      expect(result.dbUpdates.containsKey('1'), isTrue);
    });

    test('processBulkMove moves notes from deleted to active', () {
      final note1 = NotesSection(id: '1', title: 'Note 1', isDeleted: true);
      final activeNotes = <NotesSection>[];
      final deletedNotes = [note1];

      final result = RecycleOperationsService.processBulkMove(
        currentActive: activeNotes,
        currentDeleted: deletedNotes,
        targetIds: {'1'},
        toDelete: false,
      );

      expect(activeNotes, [note1]);
      expect(deletedNotes, isEmpty);
      expect(note1.isDeleted, isFalse);
      expect(result.dbUpdates.containsKey('1'), isTrue);
    });
  });
}
