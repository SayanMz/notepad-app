import 'dart:io';

import 'package:flutter/material.dart';
import 'package:notepad/core/data/app_settings_repository.dart';
import 'package:notepad/features/home/services/google_drive_service.dart';

class AuthController extends ChangeNotifier {
  // --- STATE ---
  Map<String, dynamic> storageStats = {'percent': 0.0, 'text': 'Offline'};

  // --- GETTERS ---

  /// Cached identity from local settings for instant/offline UI rendering.
  String? get displayName => appSettingsRepository.settings.userName;

  String? get displayEmail => appSettingsRepository.settings.userEmail;

  String? get avatarUrl => appSettingsRepository.settings.userAvatarUrl;

  /// Real authentication state derived from GoogleSignIn.
  bool get isAuthenticated => googleDriveService.currentUser != null;

  // If you need actual user details down the line:
  // GoogleSignInAccount? get currentUser => googleDriveService.currentUser;

  // --- METHODS ---

  /// Initializes auth state during app startup.
  Future<void> initialize() async {
    if (Platform.isAndroid || Platform.isIOS) {
      await googleDriveService.signIn();
    }

    if (isAuthenticated) {
      await fetchFreshStorageStats();
    }
  }

  /// Performs interactive login and persists user identity locally.
  Future<void> login() async {
    final success = await googleDriveService.signIn();

    if (!success) return;

    final user = googleDriveService.currentUser;

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

  /// Signs out from Google and clears local identity cache.
  Future<void> logout() async {
    await googleDriveService.signOut();

    await appSettingsRepository.update(
      appSettingsRepository.settings.copyWith(clearUser: true),
    );

    storageStats = {'percent': 0.0, 'text': 'Offline'};

    notifyListeners();
  }

  /// Refreshes Google Drive storage usage info.
  Future<void> fetchFreshStorageStats() async {
    storageStats = await googleDriveService.getDetailedStorageUsage();
  }
}

final AuthController authController = AuthController();
