// Handles the startup heavy lifting including seeding, trash purging, and maintenance.
import 'package:flutter/foundation.dart';
import 'package:notepad/core/database/app_data.dart';
import 'package:notepad/core/database/app_settings_repository.dart';
import 'package:notepad/core/database/sqlite_fts_service.dart';
import 'package:notepad/core/database/storage_service.dart';
import 'package:notepad/core/services/repo_services/seed_data_service.dart';

/// Result of the repository initialization process.
class InitializationResult {
  final List<NotesSection> activeNotes;
  final List<NotesSection> deletedNotes;
  final Map<String, NotesSection> cacheMap;

  InitializationResult({
    required this.activeNotes,
    required this.deletedNotes,
    required this.cacheMap,
  });
}

/// Service dedicated to orchestrating the complex startup logic for note data.
class NotesInitializationService {
  /// Entry point for data initialization. Handles version migrations and standard loads.
  static Future<InitializationResult> initializeData({
    required int installedSeedVersion,
    required int currentSeedVersion,
  }) async {
    final List<NotesSection> activeNotes = [];
    final List<NotesSection> deletedNotes = [];
    final Map<String, NotesSection> cacheMap = {};

    if (installedSeedVersion != currentSeedVersion) {
      await _handleMigration(activeNotes, cacheMap, currentSeedVersion);
    } else {
      await _handleStandardLoad(activeNotes, deletedNotes, cacheMap);
    }

    return InitializationResult(
      activeNotes: activeNotes,
      deletedNotes: deletedNotes,
      cacheMap: cacheMap,
    );
  }

  /// Wipes stale data and populates the database with fresh welcome notes.
  static Future<void> _handleMigration(
    List<NotesSection> activeNotes,
    Map<String, NotesSection> cacheMap,
    int currentSeedVersion,
  ) async {
    debugPrint('Migration: Resetting stale data...');
    await StorageService.clearAllNotes();

    activeNotes.addAll(SeedDataService.generateWelcomeNotes());

    for (var (i, note) in activeNotes.indexed) {
      note.positionIndex = i;
      cacheMap[note.id] = note;
    }

    await StorageService.saveNotesBulk({for (var n in activeNotes) n.id: n});
    await SqliteFtsService.reindexAllNotes(activeNotes);
    await appSettingsRepository.setSeedVersion(currentSeedVersion);
  }

  /// Loads all notes from storage and performs the automatic trash purge.
  static Future<void> _handleStandardLoad(
    List<NotesSection> activeNotes,
    List<NotesSection> deletedNotes,
    Map<String, NotesSection> cacheMap,
  ) async {
    final allNotes = StorageService.loadAllNotes();
    final Set<String> expiredNoteIds = {};

    for (final note in allNotes) {
      if (note.isDeleted && note.isExpired) {
        expiredNoteIds.add(note.id);
        continue;
      }

      cacheMap[note.id] = note;
      note.isDeleted ? deletedNotes.add(note) : activeNotes.add(note);
    }

    if (expiredNoteIds.isNotEmpty) {
      debugPrint(
        'Auto-Purge: Wiping ${expiredNoteIds.length} expired trash notes permanently.',
      );
      await StorageService.deleteNotesBulk(expiredNoteIds);
    }
  }

  /// Runs periodic database maintenance tasks (e.g. Hive compaction).
  static Future<void> runMaintenanceTasks() async {
    final lastRun = appSettingsRepository.settings.lastMaintenanceDate;
    final now = DateTime.now();

    if (lastRun == null || now.difference(lastRun).inDays >= 7) {
      debugPrint(
        'Maintenance: 7-day timeline reached. Running Hive compaction...',
      );
      try {
        await StorageService.performMaintenance();
        await appSettingsRepository.recordMaintenanceCompleted(now);
      } catch (e) {
        debugPrint('Maintenance failed, will retry next launch: $e');
      }
    }
  }
}
