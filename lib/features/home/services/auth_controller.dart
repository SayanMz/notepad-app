import 'package:flutter/material.dart';
import 'package:notepad/core/data/app_settings_repository.dart';
import 'package:notepad/features/home/services/google_drive_service.dart';

class AuthController extends ChangeNotifier {
  // --- STATE ---
  Map<String, dynamic> storageStats = {'percent': 0.0, 'text': 'Offline'};

  // --- GETTERS ---
  // Get identity from the repository so it's available offline
  String? get displayName => appSettingsRepository.settings.userName;
  String? get displayEmail => appSettingsRepository.settings.userEmail;
  String? get avatarUrl => appSettingsRepository.settings.userAvatarUrl;

  // Logical check: are we "signed in" according to our local cache?[cite: 7]
  bool get isAuthenticated => displayEmail != null;

  // --- METHODS ---

  /// Call this when the app starts
  Future<void> initialize() async {
    // Silent login ensures the service has a fresh user object if a token exists[cite: 14]
    await googleDriveService.signIn();

    if (isAuthenticated) {
      await fetchFreshStorageStats(); // Populate stats before UI renders
    }
  }

  Future<void> login() async {
    final success = await googleDriveService.signIn();
    if (success) {
      final user = googleDriveService.currentUser;

      // Update the repository (Persists to Hive)[cite: 7]
      await appSettingsRepository.update(
        appSettingsRepository.settings.copyWith(
          userName: user?.displayName,
          userEmail: user?.email,
          userAvatarUrl: user?.photoUrl,
        ),
      );

      await fetchFreshStorageStats();
    }
  }

  Future<void> logout() async {
    // 1. Wipe the local Hive cache[cite: 7]
    await appSettingsRepository.update(
      appSettingsRepository.settings.copyWith(clearUser: true),
    );

    // 2. Reset local volatile state
    storageStats = {'percent': 0.0, 'text': 'Offline'};
    notifyListeners();
  }

  Future<void> fetchFreshStorageStats() async {
    storageStats = await googleDriveService.getDetailedStorageUsage();
    notifyListeners();
  }
}
