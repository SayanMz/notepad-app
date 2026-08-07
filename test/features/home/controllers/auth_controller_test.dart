import 'package:flutter_test/flutter_test.dart';
import 'package:notepad/core/database/app_data.dart';
import 'package:notepad/core/database/app_settings_repository.dart';
import 'package:notepad/features/home/controllers/auth_controller.dart';
import 'package:notepad/features/home/services/google_drive_service.dart';

class FakeGoogleDriveService extends GoogleDriveService {
  FakeGoogleDriveService() : super.internalForTesting();

  bool signedInCalled = false;
  bool signedOutCalled = false;
  bool silentSignInCalled = false;
  bool fetchUsageCalled = false;

  @override
  Future<bool> signIn() async {
    signedInCalled = true;
    return true;
  }

  @override
  Future<void> signOut() async {
    signedOutCalled = true;
  }

  @override
  Future<bool> attemptSilentSignIn() async {
    silentSignInCalled = true;
    return true;
  }

  @override
  Future<Map<String, dynamic>> getDetailedStorageUsage() async {
    fetchUsageCalled = true;
    return {'percent': 0.5, 'text': '50% used'};
  }
}

class FakeAppSettingsRepository extends AppSettingsRepository {
  AppSettings mockSettings = const AppSettings();

  @override
  AppSettings get settings => mockSettings;

  @override
  Future<void> update(AppSettings newSettings) async {
    mockSettings = newSettings;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AuthController', () {
    late FakeGoogleDriveService driveService;
    late FakeAppSettingsRepository settingsRepo;
    late AuthController controller;

    setUp(() {
      driveService = FakeGoogleDriveService();
      settingsRepo = FakeAppSettingsRepository();
      controller = AuthController(
        driveService: driveService,
        settingsRepository: settingsRepo,
      );
    });

    test('initialize attempts silent sign-in if email exists', () async {
      settingsRepo.mockSettings = const AppSettings(userEmail: 'test@example.com');
      
      await controller.initialize();
      
      expect(driveService.silentSignInCalled, isTrue);
    });

    test('logout clears local settings and calls drive signout', () async {
      settingsRepo.mockSettings = const AppSettings(
        userName: 'Sayan',
        userEmail: 'sayan@example.com',
      );

      await controller.logout();

      expect(driveService.signedOutCalled, isTrue);
      expect(settingsRepo.mockSettings.userName, isNull);
      expect(settingsRepo.mockSettings.userEmail, isNull);
      expect(controller.storageStats['text'], 'Offline');
    });

    test('fetchFreshStorageStats updates internal state', () async {
      await controller.fetchFreshStorageStats();

      expect(driveService.fetchUsageCalled, isTrue);
      expect(controller.storageStats['text'], '50% used');
    });
  });
}
