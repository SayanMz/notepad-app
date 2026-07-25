// Auth state bridges local profile data with the live Google Drive session.
import 'package:flutter/material.dart';
import 'package:notepad/core/database/app_settings_repository.dart';
import 'package:notepad/features/home/services/google_drive_service.dart';

class AuthController extends ChangeNotifier {
  // Cached storage state is kept separately from live auth so offline UI still has a snapshot.
  Map<String, dynamic> storageStats = {'percent': 0.0, 'text': 'Offline'};

  // These values come from local settings and are available before a live sign-in finishes.
  String? get displayName => appSettingsRepository.settings.userName;
  String? get displayEmail => appSettingsRepository.settings.userEmail;
  String? get avatarUrl => appSettingsRepository.settings.userAvatarUrl;

  bool get isAuthenticated => googleDriveService.currentUser != null;

  Future<void> initialize() async {
    // Mobile platforms try silent sign-in on startup so the account state is ready early.
    if (displayEmail != null && displayEmail!.isNotEmpty) {
      await googleDriveService.attemptSilentSignIn();
    }
    if (isAuthenticated) {
      await fetchFreshStorageStats();
    }
    notifyListeners();
  }

  Future<void> login() async {
    final success = await googleDriveService.signIn();
    if (!success) return;

    final user = googleDriveService.currentUser;

    // Persist the current profile locally so the drawer can render it without another sign-in.
    await appSettingsRepository.update(
      appSettingsRepository.settings.copyWith(
        userName: user?.displayName,
        userEmail: user?.email,
        userAvatarUrl: user?.photoUrl,
      ),
    );

    await fetchFreshStorageStats();
    notifyListeners();
  }

  Future<void> logout() async {
    await googleDriveService.signOut();

    // Clearing local identity keeps the offline snapshot in sync with the signed-out state.
    await appSettingsRepository.update(
      appSettingsRepository.settings.copyWith(clearUser: true),
    );

    storageStats = {'percent': 0.0, 'text': 'Offline'};
    notifyListeners();
  }

  Future<void> fetchFreshStorageStats() async {
    // Storage usage is fetched lazily because it depends on a live authenticated session.
    storageStats = await googleDriveService.getDetailedStorageUsage();
    notifyListeners();
  }
}

final AuthController authController = AuthController();
