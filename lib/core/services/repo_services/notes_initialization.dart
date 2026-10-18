// Handles the startup heavy lifting including seeding, trash purging, and maintenance.
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:notepad/core/database/app_data.dart';
import 'package:notepad/core/database/app_settings_repository.dart';
import 'package:notepad/core/database/sqlite_fts.dart';
import 'package:notepad/core/database/storage_service.dart';
import 'package:notepad/core/database/vector_storage.dart';
import 'package:notepad/core/services/repo_services/seed_data.dart';
import 'package:notepad/core/services/search_indexer.dart';

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
    final existingNotes = StorageService.loadAllNotes();

    if (installedSeedVersion == 0 && existingNotes.isEmpty) {
      await _handleFirstInstall(activeNotes, cacheMap, currentSeedVersion);
    } else {
      await _handleStandardLoad(
        activeNotes,
        deletedNotes,
        cacheMap,
        existingNotes,
      );
    }

    return InitializationResult(
      activeNotes: activeNotes,
      deletedNotes: deletedNotes,
      cacheMap: cacheMap,
    );
  }

  /// Populates the database with fresh welcome notes on initial install.
  static Future<void> _handleFirstInstall(
    List<NotesSection> activeNotes,
    Map<String, NotesSection> cacheMap,
    int currentSeedVersion,
  ) async {
    debugPrint('First Install: Seeding welcome notes...');
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
    List<NotesSection> allNotes,
  ) async {
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
      await VectorStorageService.to.removeBulk(expiredNoteIds);
    }

    // Always reseed the RAM-backed in-memory FTS database on startup
    await SqliteFtsService.reindexAllNotes(activeNotes);

    // Maintenance check: clean up any orphaned vectors whose note_id is neither active nor in trash
    await _runOrphanVectorCleanup(cacheMap.keys.toSet());
  }

  static Future<void> _runOrphanVectorCleanup(Set<String> validNoteIds) async {
    try {
      final allEmbeddings = await VectorStorageService.to.fetchAllEmbeddings();
      final orphanIds = <String>{};
      for (final row in allEmbeddings) {
        final id = row['note_id'] as String?;
        if (id != null && !validNoteIds.contains(id)) {
          orphanIds.add(id);
        }
      }
      if (orphanIds.isNotEmpty) {
        debugPrint(
          'Orphan Vector Cleanup: Purging ${orphanIds.length} orphaned vector entries.',
        );
        await VectorStorageService.to.removeBulk(orphanIds);
      }
    } catch (e) {
      debugPrint('Orphan Vector Cleanup Error: $e');
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

  /// Triggers semantic search initialization and missing embedding sweep.
  static Future<void> runSemanticSearchMaintenance(
    List<NotesSection> activeNotes, [
    SearchIndexerApi? searchIndexer,
  ]) async {
    final indexer = searchIndexer ?? SearchIndexerApi.instance;
    await indexer.runMaintenanceSweep(activeNotes);
  }
}
