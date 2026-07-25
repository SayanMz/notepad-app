import 'dart:async';

import 'package:flutter/material.dart';
import 'package:notepad/core/constants/animation_constants.dart';
import 'package:notepad/core/database/notes_repository.dart';
import 'package:notepad/core/services/ui_management/scaffold_messenger_notifier.dart';
import 'package:notepad/features/home/controllers/auth_controller.dart';
import 'package:notepad/features/home/services/google_drive_service.dart';

// Handles backup and restore sync actions with Google Drive.
class SyncController extends ChangeNotifier {
  SyncController({
    required this.authController,
    GoogleDriveService? driveService,
    NoteRepository? repository,
  }) : _driveService = driveService ?? googleDriveService,
       _noteRepository = repository ?? noteRepository;

  final AuthController authController;
  final GoogleDriveService _driveService;
  final NoteRepository _noteRepository;

  bool _isSaving = false;
  String _statusText = 'Ready to sync';
  Color? _statusColor;
  Timer? _statusTimer;

  bool get isSaving => _isSaving;
  String get statusText => _statusText;
  Color? get statusColor => _statusColor;

  void _setSaving(bool value) {
    if (_isSaving == value) return;
    _isSaving = value;
    notifyListeners();
  }

  void updateStatus(String message, {Color? color}) {
    _statusTimer?.cancel();
    _statusText = message;
    _statusColor = color;
    notifyListeners();

    _statusTimer = Timer(AnimationConstants.snackbarLong, () {
      _statusText = 'Ready to sync';
      _statusColor = null;
      notifyListeners();
    });
  }

  Future<void> executeBackup() async {
    try {
      _setSaving(true);

      final (noteCount, jsonString) = await _noteRepository
          .exportNotesToBackupString();

      await _driveService.uploadBackup(jsonString);
      await authController.fetchFreshStorageStats();

      updateStatus('All saved', color: Colors.green);
      showSuccessSnackBar(
        '${noteCount == 1 ? '1 note' : '$noteCount notes'} are now backed up.',
      );
    } catch (e) {
      updateStatus('Sync failed', color: Colors.redAccent);
      debugPrint('Manual backup failed: $e');
    } finally {
      _setSaving(false);
    }
  }

  Future<void> executeRestore() async {
    try {
      _setSaving(true);

      final backupJson = await _driveService.downloadBackup();
      if (backupJson == null || backupJson.isEmpty) {
        updateStatus('No backup found', color: Colors.orange);
        return;
      }

      final importedNotes = await _noteRepository.importNotesFromBackupString(
        backupJson,
      );
      await authController.fetchFreshStorageStats();

      updateStatus('All saved', color: Colors.green);
      showSuccessSnackBar(
        '${importedNotes == 1 ? '1 note' : '$importedNotes notes'} have been restored.',
      );
    } catch (e) {
      updateStatus('Sync failed', color: Colors.redAccent);
      debugPrint('Manual restore failed: $e');
    } finally {
      _setSaving(false);
    }
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    super.dispose();
  }
}
