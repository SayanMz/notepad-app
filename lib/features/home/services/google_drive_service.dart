import 'dart:convert';
import 'dart:io';

import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;

// Google Drive sync boundary that keeps backup and restore concerns out of the UI.
class GoogleDriveService {
  GoogleDriveService._internal();
  static final GoogleDriveService _instance = GoogleDriveService._internal();
  factory GoogleDriveService() => _instance;

  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;
  GoogleSignInAccount? _user;
  GoogleSignInAccount? get currentUser => _user;

  String get _clientId => dotenv.env['GOOGLE_CLIENT_ID'] ?? '';
  String get _serverClientId => dotenv.env['GOOGLE_SERVER_CLIENT_ID'] ?? '';

  bool _initialized = false;
  Future<void>? _initializing;

  Future<void> _ensureInitialized() async {
    if (_initialized) return;

    final existing = _initializing;
    if (existing != null) return existing;

    final future = _googleSignIn
        .initialize(
          clientId: Platform.isWindows ? _clientId : null,
          serverClientId: Platform.isAndroid ? _serverClientId : null,
        )
        .then((_) {
          _initialized = true;
        })
        .whenComplete(() {
          _initializing = null;
        });

    _initializing = future;
    return future;
  }

  Future<bool> signIn() async {
    if (_clientId.isEmpty && Platform.isWindows) {
      throw Exception('Missing GOOGLE_CLIENT_ID in .env');
    }

    try {
      await _ensureInitialized();
      _user = await _googleSignIn.authenticate();
      return _user != null;
    } catch (e) {
      _user = null;
      debugPrint('Sign in failed: $e');
      return false;
    }
  }

  Future<bool> attemptSilentSignIn() async {
    try {
      await _ensureInitialized();
      final result = _googleSignIn.attemptLightweightAuthentication();
      if (result is Future<GoogleSignInAccount?>) {
        _user = await result;
      } else {
        _user = result;
      }
      return _user != null;
    } catch (e) {
      debugPrint('Silent sign-in skipped or failed: $e');
      return false;
    }
  }

  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
    } catch (e) {
      debugPrint('Sign out failed: $e');
    } finally {
      _user = null;
    }
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
      if (_shouldResetAuthState(e)) {
        await signOut();
      }
      return null;
    }
  }

  bool _shouldResetAuthState(Object error) {
    final message = error.toString().toLowerCase();
    return message.contains('401') ||
        message.contains('403') ||
        message.contains('unauthorized') ||
        message.contains('permission') ||
        message.contains('invalid_grant') ||
        message.contains('revoked') ||
        message.contains('token');
  }

  Future<bool> ensureAuthenticated() async {
    if (_user != null) return true;
    return await signIn();
  }

  Future<void>? _activeUpload;

  Future<void> uploadBackup(String jsonContent) async {
    if (jsonContent.trim().isEmpty) {
      debugPrint('Skipping empty backup upload.');
      return;
    }

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

    for (final file in files) {
      final fileId = file.id;
      if (fileId == null) continue;

      try {
        final response = await api.files.get(
          fileId,
          downloadOptions: drive.DownloadOptions.fullMedia,
        );

        final media = response as drive.Media;
        final List<int> dataChunks = [];

        await for (final chunk in media.stream) {
          dataChunks.addAll(chunk);
        }

        final decodedString = utf8.decode(dataChunks);
        if (decodedString.trim().isNotEmpty) {
          return decodedString;
        }
      } on FormatException catch (e) {
        debugPrint(
          'Failed to decode backup ${file.name}, trying next older version... Error: $e',
        );
      } catch (e) {
        debugPrint(
          'Failed to decode backup ${file.name}, trying next older version... Error: $e',
        );
      }
    }

    debugPrint('All available backup versions failed to decode.');
    return null;
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
      final double percent = (usage / limit).clamp(0.0, 1.0).toDouble();

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
        try {
          await api.files.delete(id);
        } catch (e) {
          debugPrint('Failed to delete old backup ${file.name}: $e');
        }
      }
    }
  }
}

final GoogleDriveService googleDriveService = GoogleDriveService();
