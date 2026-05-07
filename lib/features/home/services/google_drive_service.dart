import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:universal_platform/universal_platform.dart';

class GoogleDriveService {
  GoogleDriveService._internal();
  static final GoogleDriveService _instance = GoogleDriveService._internal();
  factory GoogleDriveService() => _instance;

  // In google_drive_service.dart
  GoogleSignInAccount? get currentUser => _googleSignIn.currentUser;

  // PASTE YOUR CLIENT ID HERE
  static const String _clientId =
      '1020980193118-3170e;opbsiecp65j8pvjvs79ntdjthha.apps.googleusercontent.com';

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    // On Android, google_sign_in finds the correct ID via your SHA-1 automatically.
    // We only provide the clientId explicitly for Windows/Web.
    clientId: (UniversalPlatform.isWindows) ? _clientId : null,
    scopes: [
      'email',
      'profile',
      'https://www.googleapis.com/auth/drive.appdata',
    ],
    //[drive.DriveApi.driveAppdataScope],
  );

  GoogleSignInAccount? _user;

  // Sign in the user
  Future<bool> signIn() async {
    try {
      // If a user is already "signed in" but the token expired,
      // silentSignIn will fix it without a popup.
      _user =
          await _googleSignIn.signInSilently() ?? await _googleSignIn.signIn();
      return _user != null;
    } catch (e) {
      debugPrint('Sign in failed: $e');
      return false;
    }
  }

  // Get the Drive API client
  Future<drive.DriveApi?> getDriveApi() async {
    final authClient = await _googleSignIn.authenticatedClient();
    return authClient != null ? drive.DriveApi(authClient) : null;
  }

  Future<void> uploadBackup(String jsonContent) async {
    final api = await getDriveApi();
    if (api == null) return;

    // 1. Encode to bytes first to get the EXACT length
    final List<int> bytes = utf8.encode(jsonContent); //
    final int exactLength = bytes.length; //

    // 2. Search for existing backup
    final fileList = await api.files.list(
      q: "name = 'notepad_backup.json'",
      spaces: 'appDataFolder',
    ); //[cite: 11]

    final drive.File fileMetadata = drive.File()
      ..name = 'notepad_backup.json'
      ..parents = ['appDataFolder']; //[cite: 11]

    // 3. Use the pre-encoded bytes for the media stream
    final media = drive.Media(
      Stream.value(bytes), // Pass the byte list directly[cite: 11]
      exactLength, // Use the exact byte length[cite: 11]
    );

    if (fileList.files != null && fileList.files!.isNotEmpty) {
      final updateMetadata = drive.File()..name = 'notepad_backup.json';
      // Update existing file
      await api.files.update(
        updateMetadata,
        fileList.files!.first.id!,
        uploadMedia: media,
      ); //[cite: 11]
    } else {
      // Create new file
      await api.files.create(fileMetadata, uploadMedia: media); //[cite: 11]
    }
  }

  Future<String?> downloadBackup() async {
    final api = await getDriveApi();
    if (api == null) return null;

    // 1. Locate the file in the hidden appData folder
    final fileList = await api.files.list(
      q: "name = 'notepad_backup.json'",
      spaces: 'appDataFolder',
    );

    // 2. Return null if no backup exists
    if (fileList.files == null || fileList.files!.isEmpty) {
      debugPrint("No backup file found in Google Drive.");
      return null;
    }

    final fileId = fileList.files!.first.id!;

    // 3. Request the actual Media content (not the File metadata)
    // The 'fullMedia' option is critical to avoid the Type Cast error.
    final response = await api.files.get(
      fileId,
      downloadOptions: drive.DownloadOptions.fullMedia,
    );

    // 4. Process the stream safely
    final drive.Media media = response as drive.Media;
    final List<int> dataChunks = [];

    try {
      await for (var chunk in media.stream) {
        dataChunks.addAll(chunk);
      }

      // 5. Convert bytes back to a JSON string
      return utf8.decode(dataChunks);
    } catch (e) {
      debugPrint("Error decoding backup data: $e");
      return null;
    }
  }

  // google_drive_service.dart
  Future<Map<String, dynamic>> getDetailedStorageUsage() async {
    final api = await getDriveApi();
    // Fallback if the user isn't signed in
    if (api == null) return {'percent': 0.0, 'text': 'Offline'};

    try {
      final about = await api.about.get($fields: 'storageQuota');
      final int usage = int.tryParse(about.storageQuota?.usage ?? '0') ?? 0;
      final int limit = int.tryParse(about.storageQuota?.limit ?? '1') ?? 1;

      // Calculate the double for the bar (0.0 to 1.0)
      double percent = usage / limit;

      // Helper to format bytes into the best unit
      String formatBytes(int bytes) {
        double gb = bytes / (1024 * 1024 * 1024);
        if (gb >= 1024) {
          double tb = gb / 1024;
          return '${tb.toStringAsFixed(1)} TB';
        }
        return '${gb.toStringAsFixed(1)} GB';
      }

      return {
        'percent': percent,
        'text': '${formatBytes(usage)} of ${formatBytes(limit)} used',
      };
    } catch (e) {
      return {'percent': 0.0, 'text': 'Error fetching stats'};
    }
  }
}

// Global access variable
final GoogleDriveService googleDriveService = GoogleDriveService();
