/*
Local device state is source of truth.
Google Drive stores snapshots only.
*/

import 'dart:convert';

import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:universal_platform/universal_platform.dart';

class GoogleDriveService {
  GoogleDriveService._internal();

  static final GoogleDriveService _instance = GoogleDriveService._internal();

  factory GoogleDriveService() => _instance;

  GoogleSignInAccount? get currentUser => _googleSignIn.currentUser;

  Future<void>? _activeUpload;

  final String _clientId = dotenv.env['GOOGLE_CLIENT_ID'] ?? '';

  late final GoogleSignIn _googleSignIn = GoogleSignIn(
    clientId: UniversalPlatform.isWindows ? _clientId : null,
    scopes: const [
      'email',
      'profile',
      'https://www.googleapis.com/auth/drive.appdata',
    ],
  );

  GoogleSignInAccount? _user;

  /// Signs in the user silently if possible,
  /// otherwise falls back to interactive login.
  Future<bool> signIn() async {
    if (_clientId.isEmpty && UniversalPlatform.isWindows) {
      throw Exception('Missing GOOGLE_CLIENT_ID in .env');
    }

    try {
      _user =
          await _googleSignIn.signInSilently() ?? await _googleSignIn.signIn();

      return _user != null;
    } catch (e) {
      debugPrint('Sign in failed: $e');
      return false;
    }
  }

  /// Signs the user out and clears cached session state.
  Future<void> signOut() async {
    await _googleSignIn.signOut();
    _user = null;
  }

  /// Returns an authenticated Google Drive API client.
  Future<drive.DriveApi?> getDriveApi() async {
    final authClient = await _googleSignIn.authenticatedClient();

    if (authClient == null) return null;

    return drive.DriveApi(authClient);
  }

  /// Ensures the user still has a valid authenticated session.
  Future<bool> ensureAuthenticated() async {
    try {
      final user = await _googleSignIn.signInSilently();

      return user != null;
    } catch (_) {
      return false;
    }
  }

  /// Uploads a new versioned backup snapshot.
  ///
  /// Uploads are serialized to prevent concurrent writes.
  Future<void> uploadBackup(String jsonContent) async {
    if (!await ensureAuthenticated()) {
      return;
    }

    if (_activeUpload != null) {
      return _activeUpload!;
    }

    try {
      _activeUpload = _performUpload(jsonContent);

      await _activeUpload;
    } finally {
      _activeUpload = null;
    }
  }

  /// Downloads the newest available backup snapshot.
  Future<String?> downloadBackup() async {
    if (!await ensureAuthenticated()) {
      return null;
    }

    final api = await getDriveApi();

    if (api == null) return null;

    final fileList = await api.files.list(
      q: "name contains 'notepad_backup_'",
      spaces: 'appDataFolder',
      orderBy: 'createdTime desc',
    );

    final files = fileList.files;

    if (files == null || files.isEmpty) {
      debugPrint('No backup file found in Google Drive.');

      return null;
    }

    final fileId = files.first.id;

    if (fileId == null) {
      return null;
    }

    final response = await api.files.get(
      fileId,
      downloadOptions: drive.DownloadOptions.fullMedia,
    );

    final media = response as drive.Media;

    final List<int> dataChunks = [];

    try {
      await for (final chunk in media.stream) {
        dataChunks.addAll(chunk);
      }

      return utf8.decode(dataChunks);
    } catch (e) {
      debugPrint('Error decoding backup data: $e');

      return null;
    }
  }

  /// Returns Google Drive storage usage information.
  Future<Map<String, dynamic>> getDetailedStorageUsage() async {
    final api = await getDriveApi();

    if (api == null) {
      return {'percent': 0.0, 'text': 'Offline'};
    }

    try {
      final about = await api.about.get($fields: 'storageQuota');

      final int usage = int.tryParse(about.storageQuota?.usage ?? '0') ?? 0;

      final int limit = int.tryParse(about.storageQuota?.limit ?? '1') ?? 1;

      final double percent = usage / limit;

      String formatBytes(int bytes) {
        final double gb = bytes / (1024 * 1024 * 1024);

        if (gb >= 1024) {
          final double tb = gb / 1024;

          return '${tb.toStringAsFixed(1)} TB';
        }

        return '${gb.toStringAsFixed(1)} GB';
      }

      return {
        'percent': percent,
        'text':
            '${formatBytes(usage)} of '
            '${formatBytes(limit)} used',
      };
    } catch (e) {
      debugPrint('Failed to fetch storage usage: $e');

      return {'percent': 0.0, 'text': 'Error fetching stats'};
    }
  }

  /// Performs the actual upload operation.
  Future<void> _performUpload(String jsonContent) async {
    final api = await getDriveApi();

    if (api == null) return;

    final timestamp = DateTime.now().millisecondsSinceEpoch;

    final backupName = 'notepad_backup_$timestamp.json';

    final List<int> bytes = utf8.encode(jsonContent);

    final media = drive.Media(Stream.value(bytes), bytes.length);

    final fileMetadata = drive.File()
      ..name = backupName
      ..parents = ['appDataFolder'];

    await api.files.create(fileMetadata, uploadMedia: media);

    await _cleanupOldBackups(api);
  }

  /// Keeps only the newest backup snapshots.
  Future<void> _cleanupOldBackups(drive.DriveApi api) async {
    final backups = await api.files.list(
      q: "name contains 'notepad_backup_'",
      spaces: 'appDataFolder',
      orderBy: 'createdTime desc',
    );

    final files = backups.files ?? [];

    if (files.length <= 3) {
      return;
    }

    for (final file in files.skip(3)) {
      final id = file.id;

      if (id != null) {
        await api.files.delete(id);
      }
    }
  }
}

final GoogleDriveService googleDriveService = GoogleDriveService();
