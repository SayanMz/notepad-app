import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:notepad/core/data/app_data.dart';

/// ------------------------------------------------------------
/// NOTE REPOSITORY
/// ------------------------------------------------------------

class NoteRepository extends ChangeNotifier {
  late final Box<NotesSection> _box = Hive.box<NotesSection>('notes_box');

  final List<NotesSection> _notes = [];
  final Map<String, NotesSection> _noteMap = {};

  final List<NotesSection> _deletedNotes = [];
  List<NotesSection> get deletedNotes => List.unmodifiable(_deletedNotes);

  List<NotesSection> get allNotes => List<NotesSection>.unmodifiable(_notes);
  List<NotesSection> get activeNotes =>
      List<NotesSection>.unmodifiable(_notes.where((note) => !note.isDeleted));
  List<NotesSection> get selectedNotes =>
      List<NotesSection>.unmodifiable(_notes.where((note) => note.isSelected));

  NotesSection? findById(String id) => _noteMap[id];

  factory NoteRepository() => _instance;
  NoteRepository._internal();
  static final NoteRepository _instance = NoteRepository._internal();

  Future<void> init() async {
    _deletedNotes.clear();
    _notes.clear();
    _noteMap.clear();

    if (_box.isEmpty) {
      _addSeedNotes();
      for (var note in _notes) {
        _noteMap[note.id] = note;
        await _box.put(note.id, note);
      }
    } else {
      for (var note in _box.values) {
        _notes.add(note);
        _noteMap[note.id] = note;
        if (note.isDeleted) _deletedNotes.add(note);
      }
    }
    _sortPinnedFirst();
  }

  @visibleForTesting
  NoteRepository.internalForTesting();

  void stressTestHive() async {
    for (int i = 0; i < 100; i++) {
      saveNote(
        noteId: null,
        title: 'Stress Test Note #$i',
        content:
            'This is a test note to check if the O(1) Map lookup remains fast.',
      );
    }
  }

  void _addSeedNotes() {
    _notes.addAll([
      NotesSection(
        title: 'Welcome to Notepad ??',
        content:
            'Your new favorite workspace.\n\n'
            '• Use the toolbar below to manually apply styles like bold, italic, or new colors.\n'
            '• Highlight text to add links or change font sizes.\n'
            '• Long-press a note on the home screen to delete it.\n\n'
            'Dive in and start typing, or check out the next note to see something cool!',
        isPinned: true,
        cardColorValue: 0xFF81A1C1,
      ),
      NotesSection(
        title: 'Meet your AI Assistant ???',
        content:
            'Why tap when you can talk?\n\n'
            'Tap the floating circle icon to activate your Voice AI. Just speak naturally to format your text.\n\n'
            'Quick commands to try right now:\n'
            '- Highlight this line and say: "Make this green"\n'
            '- Say: "Make everything bold"\n'
            '- Made a mess? Just say: "Clear all formatting" or "Nuke styles"',
        isPinned: false,
        cardColorValue: 0xFFB48EAD,
      ),
      NotesSection(
        title: 'AI Playground ??',
        content:
            'Test out the engine\'s precision right here.\n\n'
            'The golden retriever is a very intelligent dog. Because it is loyal, the dog makes a great pet.\n\n'
            'Menu items:\n'
            'Pizza\n'
            'Burger\n\n'
            'Try saying these exact commands:\n'
            '- "Make the first sentence italic"\n'
            '- "Make golden retriever huge"\n'
            '- "Underline the second instance of dog"\n'
            '- "Make menu items a checklist"\n'
            '- "Center the last paragraph"',
        isPinned: false,
        cardColorValue: 0xFFEBCB8B,
      ),
    ]);
  }

  Future<bool> toggleDeletedStatus(String noteId, bool isDeleted) async {
    final note = findById(noteId);
    if (note == null) {
      debugPrint("The note: $noteId can't be moved to Recycle bin.");
      return false;
    }

    note.isDeleted = isDeleted;

    if (isDeleted) {
      _deletedNotes.add(note);
    } else {
      _deletedNotes.removeWhere((n) => n.id == noteId);
    }

    notifyListeners();
    try {
      await _box.put(note.id, note);
    } catch (e) {
      debugPrint("Background save failed: $e");
      // Optional: Revert state if the DB write fails
    }
    return true;
  }

  Future<void> toggleDeletedStatusBulk(
    List<String> noteIds,
    bool isDeleted,
  ) async {
    if (noteIds.isEmpty) return;

    for (final id in noteIds) {
      final note = findById(id);
      if (note == null) continue;

      note.isDeleted = isDeleted;
      note.isSelected = false;

      if (isDeleted) {
        _deletedNotes.add(note);
      } else {
        _deletedNotes.removeWhere((n) => n.id == id);
      }

      notifyListeners();
      try {
        await _box.put(note.id, note);
      } catch (e) {
        debugPrint("Background save failed: $e");
        // Optional: Revert state if the DB write fails
      }
    }
  }

  Future<bool> deleteForever(String noteId) async {
    debugPrint("Attempting to delete note: $noteId");
    final note = findById(noteId);
    if (note == null) {
      debugPrint("Note not found in repository.");
      return false;
    }

    _notes.removeWhere((n) => n.id == noteId);
    _deletedNotes.removeWhere((n) => n.id == noteId);
    _noteMap.remove(noteId);

    try {
      await _box.delete(noteId);
    } catch (e) {
      debugPrint("Error deleting from local storage: $e");
      return false;
    }

    notifyListeners();
    return true;
  }

  Future<String> exportNotesToBackupString() async {
    final allNotes = _notes.map((note) => note.toJson()).toList();
    return jsonEncode(allNotes);
  }

  Future<void> importNotesFromBackupString(String jsonString) async {
    final decoded = jsonDecode(jsonString);
    if (decoded is! List) {
      throw const FormatException('Invalid backup format: expected a list.');
    }
    final importedNotes = decoded
        .map((item) {
          try {
            if (item is! Map<String, dynamic>) {
              return null;
            }

            return NotesSection.fromJson(item);
          } catch (e) {
            debugPrint('Skipping corrupted note during import: $e');
            return null;
          }
        })
        .whereType<NotesSection>()
        .toList();

    if (importedNotes.isEmpty) {
      throw const FormatException('Backup contains no valid notes.');
    }

    for (var cloudNote in importedNotes) {
      final localNote = _noteMap[cloudNote.id];

      // LOGIC: Replace existing note ONLY if cloud note has a greater updatedAt value
      if (localNote == null ||
          cloudNote.updatedAt.isAfter(localNote.updatedAt)) {
        await _box.put(cloudNote.id, cloudNote);
        _noteMap[cloudNote.id] = cloudNote;

        // UI Sync: Clean up old references before adding updated data
        _notes.removeWhere((n) => n.id == cloudNote.id);
        _deletedNotes.removeWhere((n) => n.id == cloudNote.id);

        if (cloudNote.isDeleted) {
          _deletedNotes.add(cloudNote);
        } else {
          _notes.add(cloudNote);
        }
        debugPrint('Sync: Updated ${cloudNote.title} from cloud data.');
      } else {
        debugPrint(
          'Sync: Kept local version of ${localNote.title} (Local is newer or equal).',
        );
      }
    }

    // Final sort for your LG monitor view
    _sortPinnedFirst();
  }

  bool get areAllActiveNotesSelected {
    final visibleNotes = activeNotes;
    return visibleNotes.isNotEmpty &&
        visibleNotes.every((note) => note.isSelected);
  }

  void moveOnTop(NotesSection note) {
    if (note.isPinned) return;

    _notes.remove(note);

    final pinnedCount = _notes.where((n) => n.isPinned).length;

    _notes.insert(pinnedCount, note);

    notifyListeners();
  }

  //Pinned-First, Newest-First (Descending) logic
  void _sortPinnedFirst() {
    _notes.sort((a, b) {
      if (a.isPinned != b.isPinned) {
        return a.isPinned ? -1 : 1;
      }
      return b.updatedAt.compareTo(a.updatedAt);
    });
    notifyListeners();
  }

  Future<void> togglePinStatus(String noteId) async {
    final note = findById(noteId);
    if (note == null) {
      debugPrint("The note: $noteId cannot be found toPin.");
      return;
    }

    note.isPinned = !note.isPinned;
    note.updatedAt = DateTime.now();
    _sortPinnedFirst();
    try {
      await _box.put(note.id, note);
    } catch (e) {
      // Optional: Revert memory state if DB write fails
      debugPrint("Failed to persist pin status: $e");
    }
  }

  Future<void> togglePinBulk(bool goalState) async {
    final notes = selectedNotes;
    if (notes.isEmpty) return;

    final now = DateTime.now();
    final Map<dynamic, NotesSection> entries = {};

    for (final note in notes) {
      note.isPinned = goalState;
      note.updatedAt = now;
      entries[note.id] = note;
    }
    _sortPinnedFirst();

    try {
      await _box.putAll(entries);
    } catch (e) {
      debugPrint("Bulk pin save failed: $e");
    }
  }

  void toggleSelected(String noteId) {
    final note = findById(noteId);
    if (note == null) return;

    note.isSelected = !note.isSelected;
    notifyListeners();
  }

  void setSelectAllForAllActiveNotes(bool selected) {
    for (final note in activeNotes) {
      note.isSelected = selected;
    }
    notifyListeners();
  }

  void updateColorForSelectedNotes(Color color) {
    var changed = false;
    for (final note in selectedNotes) {
      note.cardColor = color;
      changed = true;
    }
    if (changed) notifyListeners();
  }

  void updateColorPreview(Color color) {
    for (final note in selectedNotes) {
      note.cardColor = color;
    }
    notifyListeners();
  }

  void restoreColors(Map<String, Color> originalColors) {
    originalColors.forEach((id, color) {
      final note = findById(id);
      if (note != null) note.cardColor = color;
    });
    notifyListeners();
  }

  void saveSelectedColors() {
    for (final note in selectedNotes) {
      _box.put(note.id, note);
    }
  }

  void clearSelection() {
    for (final note in selectedNotes) {
      note.isSelected = false;
    }
    notifyListeners();
  }

  Future<NotesSection?> saveNote({
    required String? noteId,
    required String title,
    required String content,
    String richContent = '',
  }) async {
    final rawTitle = title.trim();
    final existingNote = noteId == null ? null : findById(noteId);

    final now = DateTime.now();

    if (existingNote != null) {
      existingNote
        ..title = rawTitle
        ..content = content
        ..richContent = richContent
        ..updatedAt = now;

      await _box.put(existingNote.id, existingNote);
      _noteMap[existingNote.id] = existingNote;
      notifyListeners();
      return existingNote;
    }

    final newNote = NotesSection(
      title: rawTitle,
      content: content,
      richContent: richContent,
      createdAt: now,
      updatedAt: now,
    );

    final pinnedCount = _notes.where((n) => n.isPinned).length;
    await _box.put(newNote.id, newNote);
    _notes.insert(pinnedCount, newNote);
    _noteMap[newNote.id] = newNote;
    notifyListeners();
    return newNote;
  }
}

final NoteRepository noteRepository = NoteRepository();
