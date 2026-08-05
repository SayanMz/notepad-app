import 'package:flutter_test/flutter_test.dart';
import 'package:notepad/core/database/notes_repository.dart';
import 'package:notepad/features/home/controllers/auth_controller.dart';
import 'package:notepad/features/home/controllers/sync_controller.dart';
import 'package:notepad/features/home/services/google_drive_service.dart';

class FakeNoteRepository extends NoteRepository {
  FakeNoteRepository() : super.internalForTesting();
  
  bool exportCalled = false;
  bool importCalled = false;
  
  @override
  Future<(int, String)> exportNotesToBackupString() async {
    exportCalled = true;
    return (5, '{"notes": []}');
  }

  @override
  Future<(int restored, int skipped)> importNotesFromBackupString(String jsonString) async {
    importCalled = true;
    return (3, 2);
  }
}

class FakeGoogleDriveService extends GoogleDriveService {
  FakeGoogleDriveService() : super.internalForTesting();

  bool uploadCalled = false;
  bool downloadCalled = false;

  @override
  Future<void> uploadBackup(String jsonContent) async {
    uploadCalled = true;
  }

  @override
  Future<String?> downloadBackup() async {
    downloadCalled = true;
    return '{"notes": []}';
  }
}

class FakeAuthController extends AuthController {
  bool fetchStatsCalled = false;
  @override
  Future<void> fetchFreshStorageStats() async {
    fetchStatsCalled = true;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SyncController', () {
    late FakeNoteRepository repository;
    late FakeGoogleDriveService driveService;
    late FakeAuthController authController;
    late SyncController syncController;

    setUp(() {
      repository = FakeNoteRepository();
      driveService = FakeGoogleDriveService();
      authController = FakeAuthController();
      syncController = SyncController(
        authController: authController,
        driveService: driveService,
        repository: repository,
      );
    });

    test('executeBackup calls export and upload', () async {
      await syncController.executeBackup();

      expect(repository.exportCalled, isTrue);
      expect(driveService.uploadCalled, isTrue);
      expect(authController.fetchStatsCalled, isTrue);
      expect(syncController.statusText, 'All saved');
    });

    test('executeRestore calls download and import', () async {
      await syncController.executeRestore();

      expect(driveService.downloadCalled, isTrue);
      expect(repository.importCalled, isTrue);
      expect(authController.fetchStatsCalled, isTrue);
      expect(syncController.statusText, 'All saved');
    });
  });
}
