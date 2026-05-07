import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:notepad/core/data/app_data.dart';

/// Thin persistence layer for App Settings.
/// (Notes persistence is handled directly by NoteRepository).
class StorageService {
  static const String _notesBoxName = 'notes_box';
  static const String _settingsBoxName = 'settings_box';

  /// Centralized box lookup so the rest of the app never repeats box keys.
  static Box<NotesSection> get _notesBox =>
      Hive.box<NotesSection>(_notesBoxName);
  static Box<AppSettings> get _settingsBox =>
      Hive.box<AppSettings>(_settingsBoxName);

  /// Helper used with `compute()` to serialize notes off the UI thread.
  static String _serializeNotesTask(List<NotesSection> notes) {
    return jsonEncode(notes.map((n) => n.toJson()).toList());
  }

  /// Helper used with `compute()` to parse imported JSON off the UI thread.
  static List<NotesSection> _parseNotesTask(String jsonString) {
    final List<dynamic> jsonList = jsonDecode(jsonString);
    return jsonList.map((json) => NotesSection.fromJson(json)).toList();
  }

  /// Returns all notes currently stored in Hive.
  static List<NotesSection> loadAllNotes() {
    return _notesBox.values.toList();
  }

  /// Persists one note by ID.
  static Future<void> saveNote(NotesSection note) async {
    await _notesBox.put(note.id, note);
  }

  /// Serializes the full notes list in a background isolate.
  static Future<String> exportAllNotesToJSON(List<NotesSection> notes) async {
    return await compute(_serializeNotesTask, notes);
  }

  /// Rebuilds a notes list from JSON without blocking the UI.
  static Future<List<NotesSection>> importNotesFromJSON(
    String jsonString,
  ) async {
    return await compute(_parseNotesTask, jsonString);
  }

  /// Deletes one note from Hive.
  static Future<void> deleteNote(String id) async {
    await _notesBox.delete(id);
  }

  /// Loads the saved settings snapshot, or returns defaults when empty.
  static AppSettings loadSettings() {
    return _settingsBox.get('current_settings') ?? const AppSettings();
  }

  /// Persists the current settings snapshot.
  static Future<void> saveSettings(AppSettings settings) async {
    await _settingsBox.put('current_settings', settings);
  }
}
