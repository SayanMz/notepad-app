import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:notepad/core/data/app_data.dart';
import 'package:notepad/features/search/models/search_date_selection.dart';
import 'package:notepad/features/search/models/search_state.dart';

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
    note.isSelected = false;

    if (isDeleted) {
      _deletedNotes.add(note);
    } else {
      _deletedNotes.removeWhere((n) => n.id == noteId);
    }

    await _box.put(note.id, note);
    notifyListeners();
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

      _box.put(note.id, note);
    }
    notifyListeners();
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

      // 1. COLLISION CHECK: Archive local note if it's fresher than the backup
      if (localNote != null &&
          localNote.updatedAt.isAfter(cloudNote.updatedAt)) {
        // SAFETY ARCHIVE: Move local version to Recycle Bin with a new ID
        final archivedNote = NotesSection(
          id: '${localNote.id}_local_conflict_${DateTime.now().millisecondsSinceEpoch}',
          title: localNote.title,
          content: localNote.content,
          richContent: localNote.richContent,
          createdAt: localNote.createdAt,
          updatedAt: localNote.updatedAt,
          isDeleted: true,
        );

        await _box.put(archivedNote.id, archivedNote);
        _noteMap[archivedNote.id] = archivedNote;
        _deletedNotes.add(archivedNote);

        debugPrint('Safety: Archived local content for ${localNote.title}');
      }

      // 2. AUTHORITATIVE CLOUD SYNC: Overwrite original ID with cloud data
      await _box.put(cloudNote.id, cloudNote);
      _noteMap[cloudNote.id] = cloudNote;

      // 3. UI SYNC: Clear old references and route to correct list
      _notes.removeWhere((n) => n.id == cloudNote.id);
      _deletedNotes.removeWhere((n) => n.id == cloudNote.id);

      if (cloudNote.isDeleted) {
        _deletedNotes.add(cloudNote);
      } else {
        _notes.add(cloudNote);
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

  DateTime? _buildBoundary(
    SearchDateSelection selection, {
    required bool isEndOfRange,
  }) {
    if (!selection.hasValues) return null;

    final now = DateTime.now();
    final year = selection.year ?? now.year;
    final month = selection.month ?? (isEndOfRange ? 12 : 1);
    final day =
        selection.day ?? (isEndOfRange ? DateTime(year, month + 1, 0).day : 1);
    final hour = selection.hour ?? (isEndOfRange ? 23 : 0);
    final minute = selection.minute ?? (isEndOfRange ? 59 : 0);

    return DateTime(year, month, day, hour, minute);
  }

  List<NotesSection> search(SearchState searchState) {
    final normalizedQuery = searchState.normalizedQuery;
    final filters = searchState.filters;

    if (normalizedQuery.isEmpty && !searchState.hasFilters) {
      return const [];
    }

    final startDate = _buildBoundary(filters.start, isEndOfRange: false);
    final endDate = _buildBoundary(filters.end, isEndOfRange: true);

    return List<NotesSection>.unmodifiable(
      activeNotes.where((note) {
        if (normalizedQuery.isNotEmpty) {
          final title = note.title.toLowerCase();
          final content = note.content.toLowerCase();
          if (!title.contains(normalizedQuery) &&
              !content.contains(normalizedQuery)) {
            return false;
          }
        }

        final date = note.updatedAt;

        if (!filters.isRangeSearch) {
          if (filters.start.year != null && date.year != filters.start.year) {
            return false;
          }
          if (filters.start.month != null &&
              date.month != filters.start.month) {
            return false;
          }
          if (filters.start.day != null && date.day != filters.start.day) {
            return false;
          }
          if (filters.start.hour != null && date.hour != filters.start.hour) {
            return false;
          }
          if (filters.start.minute != null &&
              date.minute != filters.start.minute) {
            return false;
          }
        } else {
          if (startDate != null && date.isBefore(startDate)) return false;
          if (endDate != null && date.isAfter(endDate)) return false;
        }

        return true;
      }),
    );
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

      _noteMap[existingNote.id] = existingNote;
      await _box.put(existingNote.id, existingNote);
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
    _notes.insert(pinnedCount, newNote);
    _noteMap[newNote.id] = newNote;
    await _box.put(newNote.id, newNote);
    notifyListeners();
    return newNote;
  }
}

final NoteRepository noteRepository = NoteRepository();
