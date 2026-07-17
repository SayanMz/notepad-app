// Google Drive sync only stores backups; the local database stays authoritative.
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

  GoogleSignInAccount? get currentUser => _user;

  Future<void>? _activeUpload;

  final String _clientId = dotenv.env['GOOGLE_CLIENT_ID'] ?? '';
  final String _serverClientId = dotenv.env['GOOGLE_SERVER_CLIENT_ID'] ?? '';

  // v7+ Change: GoogleSignIn is now accessed via instance
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;

  bool _initialized = false;
  GoogleSignInAccount? _user;

  Future<void> _ensureInitialized() async {
    if (_initialized) return;

    await _googleSignIn.initialize(
      clientId: UniversalPlatform.isWindows ? _clientId : null,
      serverClientId: UniversalPlatform.isAndroid ? _serverClientId : null,
    );
    _initialized = true;
  }

  Future<bool> signIn() async {
    if (_clientId.isEmpty && UniversalPlatform.isWindows) {
      throw Exception('Missing GOOGLE_CLIENT_ID in .env');
    }

    try {
      await _ensureInitialized();
      // v7+ Change: signIn() and signInSilently() are replaced by authenticate()
      _user = await _googleSignIn.authenticate();
      return _user != null;
    } catch (e) {
      debugPrint('Sign in failed: $e');
      return false;
    }
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    _user = null;
  }

  Future<drive.DriveApi?> getDriveApi() async {
    if (_user == null) {
      if (!await signIn()) return null;
    }

    try {
      // Define the scope we need for Drive app data
      const driveScopes = ['https://www.googleapis.com/auth/drive.appdata'];
      final authorization = await _user!.authorizationClient.authorizeScopes(
        driveScopes,
      );
      final authClient = authorization.authClient(scopes: driveScopes);

      return drive.DriveApi(authClient);
    } catch (e) {
      debugPrint('Auth client generation failed: $e');
      return null;
    }
  }

  Future<bool> ensureAuthenticated() async {
    if (_user != null) return true;
    return await signIn();
  }

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
    if (fileId == null) return null;

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
        'text': '${formatBytes(usage)} of ${formatBytes(limit)} used',
      };
    } catch (e) {
      debugPrint('Failed to fetch storage usage: $e');
      return {'percent': 0.0, 'text': 'Error fetching stats'};
    }
  }

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

  Future<void> _cleanupOldBackups(drive.DriveApi api) async {
    final backups = await api.files.list(
      q: "name contains 'notepad_backup_'",
      spaces: 'appDataFolder',
      orderBy: 'createdTime desc',
    );

    final files = backups.files ?? [];
    if (files.length <= 3) return;

    for (final file in files.skip(3)) {
      final id = file.id;
      if (id != null) {
        await api.files.delete(id);
      }
    }
  }
}

final GoogleDriveService googleDriveService = GoogleDriveService();
