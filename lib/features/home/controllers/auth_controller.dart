import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:notepad/core/database/app_settings_repository.dart';
import 'package:notepad/features/home/services/google_drive_service.dart';

// Auth state bridges local profile data with the live Google Drive session.
class AuthController extends ChangeNotifier {
  AuthController({
    GoogleDriveService? driveService,
    AppSettingsRepository? settingsRepository,
  }) : _driveService = driveService ?? googleDriveService,
       _settingsRepository = settingsRepository ?? appSettingsRepository;

  final GoogleDriveService _driveService;
  final AppSettingsRepository _settingsRepository;

  // Cached storage state is kept separately from live auth so offline UI still has a snapshot.
  Map<String, dynamic> storageStats = {'percent': 0.0, 'text': 'Offline'};

  // These values come from local settings and are available before a live sign-in finishes.
  String? get displayName => _settingsRepository.settings.userName;
  String? get displayEmail => _settingsRepository.settings.userEmail;

  bool get isAuthenticated => _driveService.currentUser != null;

  Future<void> initialize() async {
    // Mobile platforms try silent sign-in on startup so the account state is ready early.
    if (displayEmail != null && displayEmail!.isNotEmpty) {
      await _driveService.attemptSilentSignIn();
    }
    if (isAuthenticated) {
      await fetchFreshStorageStats();
    }
    notifyListeners();
  }

  Future<void> login() async {
    final settings = _settingsRepository.settings;

    // 1. If any user info is cached, try silent sign-in first
    if (settings.userEmail != null || settings.userAvatarBytes != null) {
      if (await _driveService.attemptSilentSignIn()) {
        await fetchFreshStorageStats();
        notifyListeners();
        return;
      }
    }

    // 2. Normal interactive sign-in as fallback
    if (!await _driveService.signIn()) return;

    final user = _driveService.currentUser;
    Uint8List? avatarBytes;

    if (user?.photoUrl != null) {
      try {
        final request = await HttpClient().getUrl(Uri.parse(user!.photoUrl!));
        final response = await request.close();
        avatarBytes = await consolidateHttpClientResponseBytes(response);
      } catch (e) {
        debugPrint('Failed to fetch avatar bytes: $e');
      }
    }

    await _settingsRepository.update(
      _settingsRepository.settings.copyWith(
        userName: user?.displayName,
        userEmail: user?.email,
        userAvatarBytes: avatarBytes,
      ),
    );

    await fetchFreshStorageStats();
    notifyListeners();
  }

  Future<void> logout() async {
    await _driveService.signOut();

    // Clearing local identity keeps the offline snapshot in sync with the signed-out state.
    await _settingsRepository.update(
      _settingsRepository.settings.copyWith(clearUser: true),
    );

    storageStats = {'percent': 0.0, 'text': 'Offline'};
    notifyListeners();
  }

  Future<void> fetchFreshStorageStats() async {
    // Storage usage is fetched lazily because it depends on a live authenticated session.
    storageStats = await _driveService.getDetailedStorageUsage();
    notifyListeners();
  }
}

final AuthController authController = AuthController();
