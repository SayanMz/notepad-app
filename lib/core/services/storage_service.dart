import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:notepad/core/data/app_data.dart';

/// ------------------------------------------------------------
/// STORAGE SERVICE (Persistence Gateway)
/// Handles all Hive I/O and Isolate-based JSON processing.
/// ------------------------------------------------------------
const String _notesBoxName = 'notes_box';
const String _settingsBoxName = 'settings_box';
const String _settingsKey = 'current_settings';
Box<NotesSection> get _notesBox => Hive.box<NotesSection>(_notesBoxName);
Box<AppSettings> get _settingsBox => Hive.box<AppSettings>(_settingsBoxName);

// --- SAFETY CHECKS ---
void _ensureNotesBoxReady() {
  if (!Hive.isBoxOpen(_notesBoxName)) {
    debugPrint(
      'StorageService Error: Attempted to access Notes box before initialization.',
    );
    throw StateError('Notes box is not open yet.');
  }
}

void _ensureSettingsBoxReady() {
  if (!Hive.isBoxOpen(_settingsBoxName)) {
    debugPrint(
      'StorageService Error: Attempted to access Settings box before initialization.',
    );
    throw StateError('Settings box is not open yet.');
  }
}

/// Performs maintenance on the Hive boxes to reclaim disk space.
/// Conceptually similar to 'defragmenting' a drive.
Future<void> performMaintenance() async {
  try {
    _ensureNotesBoxReady();

    // Only compact if the 'deleted' or 'overwritten' data
    // takes up more than 30% of the total file size.
    await _notesBox.compact(); // 👈 The Garbage Collector!

    debugPrint('StorageService: Notes box compaction complete.');
  } catch (e) {
    debugPrint('StorageService Error (Maintenance): $e');
  }
}

// --- BACKGROUND ISOLATE HELPERS ---
String _serializeNotesTask(List<NotesSection> notes) {
  try {
    final data = notes.map((n) => n.toJson()).toList();
    return jsonEncode(data);
  } catch (e) {
    // Catches formatting errors within the background isolate
    throw FormatException('Failed to serialize notes: $e');
  }
}

List<NotesSection> _parseNotesTask(String jsonString) {
  try {
    final List<dynamic> jsonList = jsonDecode(jsonString);
    return jsonList.map((json) => NotesSection.fromJson(json)).toList();
  } catch (e) {
    // Catches malformed JSON or corrupted backup files
    throw FormatException('Failed to parse backup JSON: $e');
  }
}

// --- CLOUD EXPORT / IMPORT ---
Future<String> exportNotesToJSON(List<NotesSection> notes) async {
  try {
    return await compute(_serializeNotesTask, notes);
  } catch (e) {
    debugPrint('StorageService Isolate Error (Export): $e');
    rethrow; // Let the repository handle the UI feedback
  }
}

Future<List<NotesSection>> importNotesFromJSON(String jsonString) async {
  try {
    return await compute(_parseNotesTask, jsonString);
  } catch (e) {
    debugPrint('StorageService Isolate Error (Import): $e');
    rethrow; // Let the repository handle the UI feedback
  }
}

// --- NOTES CRUD OPERATIONS ---
bool get isNotesStorageEmpty {
  try {
    _ensureNotesBoxReady();
    return _notesBox.isEmpty;
  } catch (e) {
    debugPrint('StorageService Error (isNotesStorageEmpty): $e');
    return true; // Safe fallback
  }
}

List<NotesSection> loadAllNotes() {
  try {
    _ensureNotesBoxReady();
    return _notesBox.values.toList();
  } catch (e) {
    debugPrint(
      'StorageService Error (loadAllNotes): Corrupted box or read failure. $e',
    );
    return [];
  }
}

NotesSection? getNoteById(String id) {
  try {
    _ensureNotesBoxReady();
    return _notesBox.get(id);
  } catch (e) {
    debugPrint(
      'StorageService Error (getNoteById): Failed to retrieve note $id. $e',
    );
    return null;
  }
}

Future<void> saveNote(NotesSection note) async {
  try {
    _ensureNotesBoxReady();
    await _notesBox.put(note.id, note);
  } catch (e) {
    // Typical failure point for "Disk Full" scenarios
    debugPrint(
      'StorageService Error (saveNote): Failed to persist note ${note.id}. $e',
    );
  }
}

Future<void> saveNotesBulk(Map<String, NotesSection> notes) async {
  if (notes.isEmpty) return;
  try {
    _ensureNotesBoxReady();
    await _notesBox.putAll(notes);
  } catch (e) {
    debugPrint('StorageService Error (saveNotesBulk): Bulk write failed. $e');
  }
}

Future<void> deleteNote(String id) async {
  try {
    _ensureNotesBoxReady();
    await _notesBox.delete(id);
  } catch (e) {
    debugPrint(
      'StorageService Error (deleteNote): Failed to delete note $id. $e',
    );
  }
}

Future<void> clearAllNotes() async {
  try {
    _ensureNotesBoxReady();
    await _notesBox.clear();
    await _notesBox.compact();
    debugPrint('StorageService: All notes successfully wiped from disk.');
  } catch (e) {
    debugPrint(
      'StorageService Error (clearAllNotes): Failed to wipe storage. $e',
    );
  }
}

// --- SETTINGS CRUD OPERATIONS ---
AppSettings loadSettings() {
  try {
    _ensureSettingsBoxReady(); //

    final cachedSettings = _settingsBox.get(_settingsKey); //

    if (cachedSettings == null) {
      debugPrint(
        'StorageService: No configuration found on disk. Initializing default AppSettings.',
      );
      return const AppSettings(); // Falls back to default values (including seedVersion = -1)
    }

    return cachedSettings;
  } catch (e) {
    // This ONLY runs if the database file is physically broken or corrupted!
    debugPrint(
      'StorageService CRITICAL Error (loadSettings): Disk read failed! $e',
    );
    return const AppSettings(); //
  }
}

Future<void> saveSettings(AppSettings settings) async {
  try {
    _ensureSettingsBoxReady();
    await _settingsBox.put(_settingsKey, settings);
  } catch (e) {
    debugPrint(
      'StorageService Error (saveSettings): Failed to persist settings. $e',
    );
  }
}
