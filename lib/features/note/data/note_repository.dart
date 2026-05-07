import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:notepad/core/data/app_data.dart';
import 'package:notepad/features/search/models/search_state.dart';

/// ------------------------------------------------------------
/// NOTE REPOSITORY
/// ------------------------------------------------------------
/// Centralized in-memory data manager for notes.
///
/// Responsibilities:
/// - Single source of truth for all notes
/// - CRUD operations (create, read, update, delete)
/// - UI state handling (selection, deletion flags)
/// - Persistence coordination (StorageService)
/// - Notifies UI via ChangeNotifier (Observer pattern)
///
/// Design Patterns:
/// - Repository Pattern
/// - Singleton Pattern
/// - Observer Pattern (ChangeNotifier)
///
/// Trade-offs:
/// - Combines UI state + data (simple but tightly coupled)
/// - Uses O(n) operations for search/filter (acceptable for small datasets)
/// ------------------------------------------------------------
class NoteRepository extends ChangeNotifier {
  /// The physical database
  late final Box<NotesSection> _box = Hive.box<NotesSection>('notes_box');

  /// Internal mutable list containing all notes.
  /// Includes active, deleted, and selected notes.
  final List<NotesSection> _notes =
      []; //The List provides the Order: Necessary for the ListView and sorting logic (Pinned first).

  //The Map provides the Speed: Ensures that toggling a pin, selecting a note,
  //or saving an edit happens in constant time ($O(1)$), regardless of how many notes the user has.
  final Map<String, NotesSection> _noteMap = {};

  /// Singleton setup to ensure one shared instance across app.
  NoteRepository._internal();
  static final NoteRepository _instance = NoteRepository._internal();

  /// Public constructor strictly for injecting Fakes during testing.
  @visibleForTesting
  NoteRepository.internalForTesting();

  factory NoteRepository() => _instance;

  /// ------------------------------------------------------------
  /// INITIALIZATION
  /// ------------------------------------------------------------
  /// Loads notes from storage or seeds default data.
  Future<void> init() async {
    _notes.clear();
    _noteMap.clear();

    if (_box.isEmpty) {
      _addSeedNotes();
      // To persist seed notes in Hive:
      for (var note in _notes) {
        _noteMap[note.id] = note;
        await _box.put(note.id, note);
      }
    } else {
      for (var note in _box.values) {
        _notes.add(note);
        _noteMap[note.id] = note; // Build index from storage
      }
    }
    _sortPinnedFirst();
    notifyListeners();
    //stressTestHive();
  }

  ///Stress Test
  void stressTestHive() async {
    for (int i = 0; i < 100; i++) {
      saveNote(
        noteId: null, // Forces a new ID generation
        title: 'Stress Test Note #$i',
        content:
            'This is a test note to check if the O(1) Map lookup remains fast.',
      );
    }
  }

  // ------------------------------------------------------------
  // READ OPERATIONS (O(1) Efficiency)
  // ------------------------------------------------------------

  /// Finds a note by ID using linear search.
  NotesSection? findById(String id) => _noteMap[id];

  /// Adds initial demo notes for onboarding UX.
  void _addSeedNotes() {
    _notes.addAll([
      // --- 1. THE BASICS ---
      NotesSection(
        title: 'Welcome to Notepad 🚀',
        content:
            'Your new favorite workspace.\n\n'
            '• Use the toolbar below to manually apply styles like bold, italic, or new colors.\n'
            '• Highlight text to add links or change font sizes.\n'
            '• Long-press a note on the home screen to delete it.\n\n'
            'Dive in and start typing, or check out the next note to see something cool!',
        isPinned: true,
        cardColorValue: 0xFF81A1C1, // Material Blue
      ),

      // --- 2. AI INTRODUCTION ---
      NotesSection(
        title: 'Meet your AI Assistant 🎙️',
        content:
            'Why tap when you can talk?\n\n'
            'Tap the floating circle icon to activate your Voice AI. Just speak naturally to format your text.\n\n'
            'Quick commands to try right now:\n'
            '- Highlight this line and say: "Make this green"\n'
            '- Say: "Make everything bold"\n'
            '- Made a mess? Just say: "Clear all formatting" or "Nuke styles"',
        isPinned: false,
        cardColorValue: 0xFFB48EAD, // Material Purple
      ),

      // --- 3. THE SANDBOX ---
      NotesSection(
        title: 'AI Playground 🧪',
        content:
            // Paragraph 1 (Ends with \n\n)
            'Test out the engine\'s precision right here.\n\n'
            // Paragraph 2 (Contains two sentences ending in . and one \n\n block)
            'The golden retriever is a very intelligent dog. Because it is loyal, the dog makes a great pet.\n\n'
            // Paragraph 3 (List block ending with \n\n)
            'Menu items:\n'
            'Pizza\n'
            'Burger\n\n'
            // Paragraph 4 (The last paragraph)
            'Try saying these exact commands:\n'
            '- "Make the first sentence italic"\n'
            '- "Make golden retriever huge"\n'
            '- "Underline the second instance of dog"\n'
            '- "Make menu items a checklist"\n'
            '- "Center the last paragraph"',
        isPinned: false,
        cardColorValue: 0xFFEBCB8B, // Material Amber
      ),
    ]);
  }

  // ------------------------------------------------------------
  // READ-ONLY VIEWS (GETTERS)
  // ------------------------------------------------------------

  /// Returns all notes (immutable view to prevent external mutation).
  List<NotesSection> get allNotes => List<NotesSection>.unmodifiable(_notes);

  /// Returns only active (non-deleted) notes.
  /// NOTE: Each call performs O(n) filtering.
  List<NotesSection> get activeNotes =>
      List<NotesSection>.unmodifiable(_notes.where((note) => !note.isDeleted));

  /// Returns notes currently in recycle bin.
  List<NotesSection> get deletedNotes =>
      List<NotesSection>.unmodifiable(_notes.where((note) => note.isDeleted));

  /// Returns notes currently selected in UI.
  List<NotesSection> get selectedNotes =>
      List<NotesSection>.unmodifiable(_notes.where((note) => note.isSelected));

  Future<String> exportNotesToBackupString() async {
    final allNotes = _notes.map((note) => note.toJson()).toList();
    return jsonEncode(allNotes);
  }

  Future<void> importNotesFromBackupString(String jsonString) async {
    final List<dynamic> decoded = jsonDecode(jsonString);
    final importedNotes = decoded
        .map((item) => NotesSection.fromJson(item))
        .toList();

    await _box.clear();
    await _box.addAll(importedNotes);
    _notes.clear();
    _notes.addAll(importedNotes);
    notifyListeners();
  }

  /// Determines if all visible notes are selected.
  /// Used for "Select All" checkbox logic.
  bool get areAllActiveNotesSelected {
    final visibleNotes = activeNotes;
    return visibleNotes.isNotEmpty &&
        visibleNotes.every((note) => note.isSelected);
  }

  /// Moves a note just below pinned notes.
  /// Maintains pinned-first ordering invariant.
  void moveOnTop(NotesSection note) {
    if (note.isPinned) return;

    _notes.remove(note);

    final pinnedCount = _notes.where((n) => n.isPinned).length;

    _notes.insert(pinnedCount, note);

    notifyListeners();
  }

  void _sortPinnedFirst() {
    _notes.sort((a, b) {
      if (a.isPinned == b.isPinned) return 0;
      return a.isPinned ? -1 : 1;
    });
  }

  /// Toggles pin state for a note and reorders pinned items first.
  void togglePin(String noteId) {
    final note = findById(noteId);
    if (note == null) return;

    note.isPinned = !note.isPinned;
    _sortPinnedFirst();
    _box.put(note.id, note);
    notifyListeners();
  }

  /// Toggles selection for a single note.
  void toggleSelected(String noteId) {
    final note = findById(noteId);
    if (note == null || note.isDeleted) return;

    note.isSelected = !note.isSelected;
    _box.put(note.id, note);
    notifyListeners();
  }

  /// Selects or clears all active notes.
  void setSelectAllForAllActiveNotes(bool selected) {
    for (final note in activeNotes) {
      note.isSelected = selected;
      _box.put(note.id, note);
    }
    notifyListeners();
  }

  /// Applies a new color to every selected note.
  void updateColorForSelectedNotes(Color color) {
    var changed = false;
    for (final note in selectedNotes) {
      note.cardColor = color;
      _box.put(note.id, note);
      changed = true;
    }
    if (changed) notifyListeners();
  }

  void updateColorPreview(Color color) {
    for (final note in selectedNotes) {
      note.cardColor = color; // Update object in memory
    }
    notifyListeners();
  }

  void restoreColors(Map<String, Color> originalColors) {
    originalColors.forEach((id, color) {
      final note = findById(id);
      if (note != null) note.cardColor = color;
    });
    notifyListeners(); // Refresh UI to show original colors[cite: 14]
  }

  void saveSelectedColors() {
    for (final note in selectedNotes) {
      _box.put(note.id, note); // Write final state to disk once[cite: 14]
    }
  }

  /// Clears selection from all notes.
  void clearSelection() {
    var changed = false;
    for (final note in _notes) {
      if (!note.isSelected) continue;
      note.isSelected = false;
      _box.put(note.id, note);
      changed = true;
    }
    if (changed) notifyListeners();
  }

  /// Moves selected notes to the recycle bin.
  void moveSelectedNotesToRecycleBin(List<NotesSection> notes) {
    for (final note in notes) {
      final existing = findById(note.id);
      if (existing == null) continue;
      existing.isDeleted = true;
      existing.isSelected = false;
      _box.put(existing.id, existing);
    }
    notifyListeners();
  }

  /// Restores a note from the recycle bin.
  void restoreNote(String noteId) {
    final note = findById(noteId);
    if (note == null) return;

    note.isDeleted = false;
    note.isSelected = false;
    _box.put(note.id, note);
    _sortPinnedFirst();
    notifyListeners();
  }

  ///It filters notes using keyword matching and optional date or range filters,
  ///builds dynamic date boundaries, and returns immutable results for safety.
  List<NotesSection> search(SearchState searchState) {
    /// Normalized query (trimmed + lowercase)
    final normalizedQuery = searchState.normalizedQuery;

    /// Extract filter configuration
    final filters = searchState.filters;

    /// Early exit:
    /// No query AND no filters → no meaningful search
    if (normalizedQuery.isEmpty && !searchState.hasFilters) {
      return const [];
    }

    return List<NotesSection>.unmodifiable(
      activeNotes.where((note) {
        /// ---------------------------------------------------------------
        /// TEXT MATCHING (TITLE + CONTENT)
        /// ---------------------------------------------------------------
        ///
        /// Case-insensitive substring search
        /// Rejects note early if no match found
        if (normalizedQuery.isNotEmpty) {
          final title = note.title.toLowerCase();
          final content = note.content.toLowerCase();

          if (!title.contains(normalizedQuery) &&
              !content.contains(normalizedQuery)) {
            return false;
          }
        }

        /// Reference timestamp used for filtering
        final date = note.updatedAt;

        /// ---------------------------------------------------------------
        /// SINGLE DATE/TIME FILTER MODE
        /// ---------------------------------------------------------------
        ///
        /// Applies exact matching on individual components
        /// (year, month, day, hour, minute)
        if (!filters.isRangeSearch) {
          /// Year filter
          if (filters.startYear != null &&
              date.year.toString() != filters.startYear) {
            return false;
          }

          /// Month filter (zero-padded)
          if (filters.startMonth != null &&
              date.month.toString().padLeft(2, '0') != filters.startMonth) {
            return false;
          }

          /// Day filter (zero-padded)
          if (filters.startDay != null &&
              date.day.toString().padLeft(2, '0') != filters.startDay) {
            return false;
          }

          /// Hour filter (zero-padded)
          if (filters.startHour != null &&
              date.hour.toString().padLeft(2, '0') != filters.startHour) {
            return false;
          }

          /// Minute filter (zero-padded)
          if (filters.startMinute != null &&
              date.minute.toString().padLeft(2, '0') != filters.startMinute) {
            return false;
          }
        } else {
          /// -------------------------------------------------------------
          /// RANGE FILTER MODE
          /// -------------------------------------------------------------
          ///
          /// Builds start/end DateTime boundaries dynamically
          /// based on partial user input
          DateTime? createBoundary({
            String? y,
            String? m,
            String? d,
            String? h,
            String? min,
            required bool isEndOfRange,
          }) {
            /// If no components provided → no boundary
            if (y == null &&
                m == null &&
                d == null &&
                h == null &&
                min == null) {
              return null;
            }

            final now = DateTime.now();

            /// Fallback logic:
            /// - Start boundary → earliest possible values
            /// - End boundary → latest possible values
            final year = int.tryParse(y ?? '') ?? now.year;
            final month = int.tryParse(m ?? '') ?? (isEndOfRange ? 12 : 1);

            /// Dart trick for Leap-year:
            /// DateTime(year, month + 1, 0) → last day of prev month
            final day =
                int.tryParse(d ?? '') ??
                (isEndOfRange ? DateTime(year, month + 1, 0).day : 1);

            final hour = int.tryParse(h ?? '') ?? (isEndOfRange ? 23 : 0);
            final minute = int.tryParse(min ?? '') ?? (isEndOfRange ? 59 : 0);

            return DateTime(year, month, day, hour, minute);
          }

          /// Construct range boundaries
          final startDate = createBoundary(
            y: filters.startYear,
            m: filters.startMonth,
            d: filters.startDay,
            h: filters.startHour,
            min: filters.startMinute,
            isEndOfRange: false,
          );

          final endDate = createBoundary(
            y: filters.endYear,
            m: filters.endMonth,
            d: filters.endDay,
            h: filters.endHour,
            min: filters.endMinute,
            isEndOfRange: true,
          );

          /// -------------------------------------------------------------
          /// RANGE VALIDATION
          /// -------------------------------------------------------------
          ///
          /// Short-circuit evaluation:
          /// - Reject early if outside boundaries
          if (startDate != null && date.isBefore(startDate)) return false;
          if (endDate != null && date.isAfter(endDate)) return false;
        }

        /// If all conditions pass → include note
        return true;
      }),
    );
  }

  // ------------------------------------------------------------
  // SMART SAVE (CREATE / UPDATE)
  // ------------------------------------------------------------

  /// Handles:
  /// - Create (new note)
  /// - Update (existing note)
  /// - No-op (if nothing changed)
  ///
  /// Optimization:
  /// Prevents unnecessary updates if content unchanged.
  NotesSection? saveNote({
    required String? noteId,
    required String title,
    required String content,
    String richContent = '',
  }) {
    final rawTitle = title.trim();
    final existingNote = noteId == null ? null : findById(noteId);

    final now = DateTime.now();

    if (existingNote != null) {
      existingNote
        ..title = rawTitle
        ..content = content
        ..richContent = richContent
        ..updatedAt = now;

      _box.put(existingNote.id, existingNote);
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
    _box.put(newNote.id, newNote);
    notifyListeners();
    return newNote;
  }

  /// Soft delete: moves notes to recycle bin.
  void moveToRecycleBin(List<String> noteIds) {
    for (final noteId in noteIds) {
      final note = findById(noteId);
      if (note != null) {
        note.isDeleted = true;
        note.isSelected = false;
        _box.put(note.id, note);
      }
    }
    notifyListeners();
  }

  /// Soft delete: moves one note to recycle bin.
  void moveToRecycleBinSingle(String noteId) {
    final note = findById(noteId);
    if (note != null) {
      note.isDeleted = true;
      note.isSelected = false;
      _box.put(note.id, note);
      notifyListeners();
    }
  }

  /// Permanently deletes a note.
  bool deleteForever(String noteId) {
    debugPrint("Listener fired from note_repository deleteForever");
    final note = findById(noteId);
    if (note == null) return false;

    _notes.removeWhere((n) => n.id == noteId);
    _noteMap.remove(noteId);
    _box.delete(noteId);
    notifyListeners();
    return true;
  }
}

/// Shared singleton for the feature layer.
final NoteRepository noteRepository = NoteRepository();
