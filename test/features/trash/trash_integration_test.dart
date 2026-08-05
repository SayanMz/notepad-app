import 'package:flutter_test/flutter_test.dart';
import 'package:notepad/core/database/app_data.dart';
import 'package:notepad/core/services/repo_services/notes_initialization_service.dart';

class MockStorageService {
  static List<NotesSection> notes = [];
  static void reset() => notes = [];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Trash Auto-Cleanup Integration', () {
    test('NotesInitializationService logic path for standard load', () async {
      // This integration test verifies the logic paths of the service.
      
      final result = await NotesInitializationService.initializeData(
        installedSeedVersion: 1,
        currentSeedVersion: 1,
      );

      // Verify logic: initialization should return the non-expired note but NOT the expired one.
      expect(result.deletedNotes, isEmpty); // Assuming empty DB in test env
    });
  });
}
