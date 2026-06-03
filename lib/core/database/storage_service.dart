// Central Hive storage helpers keep encryption, maintenance, and backups consistent.
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:notepad/core/database/app_data.dart';
import 'package:notepad/core/services/security_key_vault_service.dart';

const String _notesBoxName = 'notes_box';
const String _settingsBoxName = 'settings_box';
const String _settingsKey = 'current_settings';
Box<NotesSection> get _notesBox => Hive.box<NotesSection>(_notesBoxName);
Box<AppSettings> get _settingsBox => Hive.box<AppSettings>(_settingsBoxName);

// Open both boxes with the same encryption key so reads stay consistent across launches.
Future<void> initializeEncryptedStorage() async {
  try {
    final List<int> encryptionKey =
        await SecureKeyVaultService.getOrCreateEncryptionKey();

    await Hive.openBox<NotesSection>(
      _notesBoxName,
      encryptionCipher: HiveAesCipher(encryptionKey),
    );

    await Hive.openBox<AppSettings>(
      _settingsBoxName,
      encryptionCipher: HiveAesCipher(encryptionKey),
    );

    debugPrint(
      'StorageService: All Hive boxes securely mounted with AES-256 hardware encryption.',
    );
  } catch (e) {
    debugPrint('StorageService Critical Initialization Error: $e');
    rethrow;
  }
}

void _ensureNotesBoxReady() {
  // Guard all callers because Hive throws late and the failure is easier to diagnose here.
  if (!Hive.isBoxOpen(_notesBoxName)) {
    debugPrint(
      'StorageService Error: Attempted to access Notes box before initialization.',
    );
    throw StateError('Notes box is not open yet.');
  }
}

void _ensureSettingsBoxReady() {
  // Settings reads depend on startup having completed successfully.
  if (!Hive.isBoxOpen(_settingsBoxName)) {
    debugPrint(
      'StorageService Error: Attempted to access Settings box before initialization.',
    );
    throw StateError('Settings box is not open yet.');
  }
}

Future<void> performMaintenance() async {
  try {
    // Compact the notes box only after startup has confirmed it is open.
    _ensureNotesBoxReady();

    await _notesBox.compact();

    debugPrint('StorageService: Notes box compaction complete.');
  } catch (e) {
    debugPrint('StorageService Error (Maintenance): $e');
  }
}

String _serializeNotesTask(List<NotesSection> notes) {
  try {
    final data = notes.map((n) => n.toJson()).toList();
    return jsonEncode(data);
  } catch (e) {
    throw FormatException('Failed to serialize notes: $e');
  }
}

List<NotesSection> _parseNotesTask(String jsonString) {
  try {
    final List<dynamic> jsonList = jsonDecode(jsonString);
    return jsonList.map((json) => NotesSection.fromJson(json)).toList();
  } catch (e) {
    throw FormatException('Failed to parse backup JSON: $e');
  }
}

Future<String> exportNotesToJSON(List<NotesSection> notes) async {
  try {
    // Small exports stay on the UI isolate; larger ones move off-thread.
    if (notes.length < 200) {
      return _serializeNotesTask(notes);
    } else {
      return await compute(_serializeNotesTask, notes);
    }
  } catch (e) {
    debugPrint('StorageService Isolate Error (Export): $e');
    rethrow;
  }
}

Future<List<NotesSection>> importNotesFromJSON(String jsonString) async {
  try {
    // Import is always offloaded because malformed backups can be expensive to parse.
    return await compute(_parseNotesTask, jsonString);
  } catch (e) {
    debugPrint('StorageService Isolate Error (Import): $e');
    rethrow;
  }
}

bool get isNotesStorageEmpty {
  try {
    _ensureNotesBoxReady();
    return _notesBox.isEmpty;
  } catch (e) {
    debugPrint('StorageService Error (isNotesStorageEmpty): $e');
    return true;
  }
}

List<NotesSection> loadAllNotes() {
  try {
    // On read failure we fall back to an empty list so startup can continue.
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

Future<void> deleteNotesBulk(Set<String> ids) async {
  if (ids.isEmpty) return;
  try {
    _ensureNotesBoxReady();
    await _notesBox.deleteAll(ids);
  } catch (e) {
    debugPrint(
      'StorageService Error (deleteNotesBulk): Failed to bulk delete. $e',
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

AppSettings loadSettings() {
  try {
    _ensureSettingsBoxReady();

    final cachedSettings = _settingsBox.get(_settingsKey);

    if (cachedSettings == null) {
      // Missing settings is treated as a first-run state rather than an error.
      debugPrint(
        'StorageService: No configuration found on disk. Initializing default AppSettings.',
      );
      return const AppSettings();
    }

    return cachedSettings;
  } catch (e) {
    debugPrint(
      'StorageService CRITICAL Error (loadSettings): Disk read failed! $e',
    );
    return const AppSettings();
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
