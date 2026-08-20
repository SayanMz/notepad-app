import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:notepad/core/database/app_data.dart';
import 'package:notepad/core/database/security_key_vault_service.dart';

abstract class StorageServiceApi {
  Future<void> initializeEncryptedStorage();
  Future<void> performMaintenance();
  Future<String> exportNotesToJSON(List<NotesSection> notes);
  Future<List<NotesSection>> importNotesFromJSON(String jsonString);
  List<NotesSection> loadAllNotes();
  NotesSection? getNoteById(String id);
  Future<void> saveNote(NotesSection note);
  Future<void> saveNotesBulk(Map<String, NotesSection> notes);
  Future<void> deleteNote(String id);
  Future<void> deleteNotesBulk(Set<String> ids);
  Future<void> clearAllNotes();
  AppSettings loadSettings();
  Future<void> saveSettings(AppSettings settings);
}

// Orchestrates persistent local data storage using encrypted Hive boxes,
// providing unified CRUD operations, maintenance, and backup utilities.
class StorageService {
  static StorageServiceApi to = _StorageServiceImpl();

  static Future<void> initializeEncryptedStorage() =>
      to.initializeEncryptedStorage();

  static Future<void> performMaintenance() => to.performMaintenance();

  static Future<String> exportNotesToJSON(List<NotesSection> notes) =>
      to.exportNotesToJSON(notes);

  static Future<List<NotesSection>> importNotesFromJSON(String jsonString) =>
      to.importNotesFromJSON(jsonString);

  static List<NotesSection> loadAllNotes() => to.loadAllNotes();

  static NotesSection? getNoteById(String id) => to.getNoteById(id);

  static Future<void> saveNote(NotesSection note) => to.saveNote(note);

  static Future<void> saveNotesBulk(Map<String, NotesSection> notes) =>
      to.saveNotesBulk(notes);

  static Future<void> deleteNote(String id) => to.deleteNote(id);

  static Future<void> deleteNotesBulk(Set<String> ids) => to.deleteNotesBulk(ids);

  static Future<void> clearAllNotes() => to.clearAllNotes();

  static AppSettings loadSettings() => to.loadSettings();

  static Future<void> saveSettings(AppSettings settings) =>
      to.saveSettings(settings);
}

class _StorageServiceImpl implements StorageServiceApi {
  static const String _notesBoxName = 'notes_box';
  static const String _settingsBoxName = 'settings_box';
  static const String _settingsKey = 'current_settings';

  Box<NotesSection> get _notesBox => Hive.box<NotesSection>(_notesBoxName);
  Box<AppSettings> get _settingsBox => Hive.box<AppSettings>(_settingsBoxName);

  /// Opens both boxes with the same encryption key so reads stay consistent across launches.
  @override
  Future<void> initializeEncryptedStorage() async {
    try {
      if (!Hive.isAdapterRegistered(NotesSectionAdapter().typeId)) {
        Hive.registerAdapter(NotesSectionAdapter());
      }
      if (!Hive.isAdapterRegistered(AppSettingsAdapter().typeId)) {
        Hive.registerAdapter(AppSettingsAdapter());
      }

      final List<int> encryptionKey =
          await SecureKeyVaultService.getOrCreateEncryptionKey();

      await Future.wait([
        Hive.openBox<NotesSection>(
          _notesBoxName,
          encryptionCipher: HiveAesCipher(encryptionKey),
        ),
        Hive.openBox<AppSettings>(
          _settingsBoxName,
          encryptionCipher: HiveAesCipher(encryptionKey),
        ),
      ]);

      debugPrint(
        'StorageService: All Hive boxes securely mounted with AES-256 hardware encryption.',
      );
    } catch (e) {
      debugPrint('StorageService Critical Initialization Error: $e');
      rethrow;
    }
  }

  @override
  Future<void> performMaintenance() async {
    try {
      await _notesBox.compact();
      debugPrint('StorageService: Notes box compaction complete.');
    } catch (e) {
      debugPrint('StorageService Error (Maintenance): $e');
    }
  }

  static String _serializeNotesTask(List<NotesSection> notes) {
    try {
      final data = notes.map((n) => n.toJson()).toList();
      return jsonEncode(data);
    } catch (e) {
      throw FormatException('Failed to serialize notes: $e');
    }
  }

  static List<NotesSection> _parseNotesTask(String jsonString) {
    try {
      final List<dynamic> jsonList = jsonDecode(jsonString);
      return jsonList.map((json) => NotesSection.fromJson(json)).toList();
    } catch (e) {
      throw FormatException('Failed to parse backup JSON: $e');
    }
  }

  @override
  Future<String> exportNotesToJSON(List<NotesSection> notes) async {
    try {
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

  @override
  Future<List<NotesSection>> importNotesFromJSON(String jsonString) async {
    try {
      return await compute(_parseNotesTask, jsonString);
    } catch (e) {
      debugPrint('StorageService Isolate Error (Import): $e');
      rethrow;
    }
  }

  @override
  List<NotesSection> loadAllNotes() {
    try {
      return _notesBox.values.toList();
    } catch (e) {
      return [];
    }
  }

  @override
  NotesSection? getNoteById(String id) {
    try {
      return _notesBox.get(id);
    } catch (e) {
      return null;
    }
  }

  @override
  Future<void> saveNote(NotesSection note) async {
    try {
      await _notesBox.put(note.id, note);
    } catch (e) {
      debugPrint('StorageService Error (saveNote): ${note.id}. $e');
    }
  }

  @override
  Future<void> saveNotesBulk(Map<String, NotesSection> notes) async {
    if (notes.isEmpty) return;
    try {
      await _notesBox.putAll(notes);
    } catch (e) {
      debugPrint('StorageService Error (saveNotesBulk): $e');
    }
  }

  @override
  Future<void> deleteNote(String id) async {
    try {
      await _notesBox.delete(id);
    } catch (e) {
      debugPrint('StorageService Error (deleteNote): $id. $e');
    }
  }

  @override
  Future<void> deleteNotesBulk(Set<String> ids) async {
    if (ids.isEmpty) return;
    try {
      await _notesBox.deleteAll(ids);
    } catch (e) {
      debugPrint('StorageService Error (deleteNotesBulk): $e');
    }
  }

  @override
  Future<void> clearAllNotes() async {
    try {
      await _notesBox.clear();
      await _notesBox.compact();
    } catch (e) {
      debugPrint('StorageService Error (clearAllNotes): $e');
    }
  }

  @override
  AppSettings loadSettings() {
    try {
      return _settingsBox.get(_settingsKey) ?? const AppSettings();
    } catch (e) {
      debugPrint('StorageService Error (loadSettings): $e');
      return const AppSettings();
    }
  }

  @override
  Future<void> saveSettings(AppSettings settings) async {
    try {
      await _settingsBox.put(_settingsKey, settings);
    } catch (e) {
      debugPrint('StorageService Error (saveSettings): $e');
    }
  }
}
