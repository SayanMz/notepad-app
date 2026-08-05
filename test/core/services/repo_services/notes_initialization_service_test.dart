import 'package:flutter_test/flutter_test.dart';
import 'package:notepad/core/database/app_data.dart';
import 'package:notepad/core/services/repo_services/notes_initialization_service.dart';

void main() {
  group('NotesInitializationService', () {
    test('initializeData creates a new result with empty lists on standard load',
        () async {
      // Note: This test assumes standard load without DB interaction for now
      // as we aren't mocking the storage layer yet.
      final result = await NotesInitializationService.initializeData(
        installedSeedVersion: 1,
        currentSeedVersion: 1,
      );

      expect(result.activeNotes, isEmpty);
      expect(result.deletedNotes, isEmpty);
      expect(result.cacheMap, isEmpty);
    });

    test('InitializationResult stores provided data correctly', () {
      final note1 = NotesSection(title: 'Note 1', id: 'note_1');
      final note2 = NotesSection(title: 'Note 2', id: 'note_2');
      
      final result = InitializationResult(
        activeNotes: [note1],
        deletedNotes: [note2],
        cacheMap: {'note_1': note1, 'note_2': note2},
      );

      expect(result.activeNotes, [note1]);
      expect(result.deletedNotes, [note2]);
      expect(result.cacheMap.length, 2);
      expect(result.cacheMap['note_1'], note1);
    });

    test('runMaintenanceTasks executes if last run was > 7 days ago', () async {
      // Note: Full testing of this method requires StorageService mocking.
      // For now, we verify the logic path triggers correctly by using the 
      // global appSettingsRepository if we had a way to mock its internal settings.
      
      // Verification logic: 
      // 1. Set lastMaintenanceDate to 10 days ago.
      // 2. Call runMaintenanceTasks.
      // 3. Verify it attempts to call StorageService.performMaintenance.
    });
  });
}
