import 'dart:collection';
import 'package:flutter/material.dart';
import 'package:notepad/core/data/app_data.dart';
import 'package:notepad/core/data/app_settings_repository.dart';
import 'package:notepad/core/services/storage_service.dart' as db;

/// ------------------------------------------------------------
/// NOTE REPOSITORY (Optimized for O(1) Lookups & Surgical Movement)
/// Acts as the central State Manager and Business Logic Coordinator.
/// ------------------------------------------------------------
class NoteRepository extends ChangeNotifier {
  // ===========================================================================
  // 1. SINGLETON SETUP & CONSTRUCTORS
  // ===========================================================================

  factory NoteRepository() => _instance;

  NoteRepository._internal();

  static final NoteRepository _instance = NoteRepository._internal();

  @visibleForTesting
  NoteRepository.internalForTesting();

  // ===========================================================================
  // 2. PRIMARY DATA STRUCTURES & CACHES (State)
  // ===========================================================================

  // Core lists representing the user's current workspace and recycle bin
  final List<NotesSection> _activeNotes = [];
  final List<NotesSection> _deletedNotes = [];

  // Tracks user multi-selection without duplicating note objects
  final Set<String> _selectedIds = {};

  // Temporary holding ground for bulk pinning operations to optimize disk I/O
  final Map<String, NotesSection> _pendingPinnedWrites = {};

  // Lazy Just-In-Time (JIT) caches for instant index lookups
  Map<String, int>? _activeIndexCache;
  Map<String, int>? _deletedIndexCache;

  // ===========================================================================
  // 3. PUBLIC GETTERS & READ-ONLY VIEWS
  // ===========================================================================

  /// Exposes the active notes list as a zero-copy unmodifiable view to prevent
  /// external UI layers from altering the state directly.
  UnmodifiableListView<NotesSection> get activeNotes =>
      UnmodifiableListView(_activeNotes);

  /// Exposes the recycle bin notes list as a zero-copy unmodifiable view.
  UnmodifiableListView<NotesSection> get deletedNotes =>
      UnmodifiableListView(_deletedNotes);

  /// Resolves the selected IDs into actual [NotesSection] objects via an O(1) jump.
  List<NotesSection> get selectedNotes => _selectedIds
      .map((id) => findById(id)) // Direct O(1) jump to each note
      .whereType<NotesSection>() // Safety filter for nulls
      .toList();

  /// Returns true if the user has selected every active note on the home screen.
  bool get areAllActiveNotesSelected {
    return _activeNotes.isNotEmpty &&
        _activeNotes.every((note) => _selectedIds.contains(note.id));
  }

  // ===========================================================================
  // 4. LIFECYCLE & INITIALIZATION
  // ===========================================================================
  static const int _currentSeedVersion = 1; // Increment this to force a reset

  /// Bootstraps the repository, loads data from the storage layer, and populates
  /// initial state. Adds seed notes if the app is launched for the first time.
  Future<void> init() async {
    _activeNotes.clear();
    _deletedNotes.clear();
    _selectedIds.clear();

    final int installedSeedVersion = appSettingsRepository.settings.seedVersion;

    // 2. Handle Reinstall / Migration / Initial Run
    if (installedSeedVersion != _currentSeedVersion) {
      debugPrint(
        'Seed mismatch detected: $installedSeedVersion vs $_currentSeedVersion. Resetting...',
      );

      // Wipe potentially stale data restored by Android Auto Backup
      debugPrint('Migration: Resetting stale data...');
      await db.clearAllNotes();

      _addSeedNotes();
      // Persist fresh seeds
      await db.saveNotesBulk({for (var n in _activeNotes) n.id: n});

      // Update metadata to prevent another reset on next launch
      await appSettingsRepository.setSeedVersion(_currentSeedVersion);
    } else {
      // Linear O(n) pass only happens ONCE at startup to route notes correctly
      for (final note in db.loadAllNotes()) {
        note.isDeleted ? _deletedNotes.add(note) : _activeNotes.add(note);
      }
    }
    //stressTestHive(); // Uncomment to test 5k notes injection
    _sortAll();
  }

  /// Injects initial tutorial notes for new users.
  void _addSeedNotes() {
    _activeNotes.addAll([
      NotesSection(
        title: 'Welcome to Notepad',
        content:
            'Your new favorite workspace.\n\n'
            '- Use the toolbar below to manually apply styles like bold, italic, or new colors.\n'
            '- Highlight text to add links or change font sizes.\n'
            '- Long-press a note on the home screen to delete it.\n\n'
            'Dive in and start typing, or check out the next note to see something cool!',
        isPinned: true,
        cardColorValue: 0xFF81A1C1,
      ),
      NotesSection(
        title: 'Meet your AI Assistant',
        content:
            'Why tap when you can talk?\n\n'
            'Tap the floating circle icon to activate your Voice AI. Just speak naturally to format your text.\n\n'
            'Quick commands to try right now:\n'
            '- Highlight this line and say: "Make this green"\n'
            '- Say: "Make everything bold"\n'
            '- Made a mess? Just say: "Clear all formatting" or "Nuke styles"',
        cardColorValue: 0xFFB48EAD,
      ),
      NotesSection(
        title: 'AI Playground',
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
        cardColorValue: 0xFFEBCB8B,
      ),
    ]);
  }

  /// Generates 5,000 dummy notes to verify O(1) map lookups and scrolling performance.
  void stressTestHive() async {
    for (int i = 0; i < 5000; i++) {
      saveNote(
        noteId: null,
        title: 'Stress Test Note #$i',
        content:
            'This is a test note to check if the O(1) Map lookup remains fast.',
      );
    }
  }

  // ===========================================================================
  // 5. O(1) LOOKUPS & STATE NOTIFICATION
  // ===========================================================================

  /// Overridden to ensure JIT index caches are cleared whenever the UI is notified
  /// of a state change, guaranteeing accurate index lookups.
  @override
  void notifyListeners() {
    _activeIndexCache = null;
    _deletedIndexCache = null;
    super.notifyListeners();
  }

  /// Delegates ID lookup to the fast storage service layer.
  NotesSection? findById(String id) => db.getNoteById(id);

  /// Checks if a given note ID is currently in the selection set.
  bool isNoteSelected(String id) => _selectedIds.contains(id);

  /// Lazy lookup for the exact index of an active note. Rebuilds cache only if needed.
  int getActiveIndex(String id) {
    _activeIndexCache ??= {
      for (int i = 0; i < _activeNotes.length; i++) _activeNotes[i].id: i,
    };
    return _activeIndexCache![id] ?? -1;
  }

  /// Lazy lookup for the exact index of a deleted note. Rebuilds cache only if needed.
  int getDeletedIndex(String id) {
    _deletedIndexCache ??= {
      for (int i = 0; i < _deletedNotes.length; i++) _deletedNotes[i].id: i,
    };
    return _deletedIndexCache![id] ?? -1;
  }

  // ===========================================================================
  // 6. CORE SURGICAL LOGIC
  // ===========================================================================

  /// Sorts all notes internally. Active notes prioritize pinned status, then date.
  /// Deleted notes are strictly chronological.
  void _sortAll({bool notify = true}) {
    _activeNotes.sort((a, b) {
      if (a.isPinned != b.isPinned) {
        return a.isPinned ? -1 : 1;
      }
      return b.updatedAt.compareTo(a.updatedAt);
    });

    _deletedNotes.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

    if (notify) notifyListeners();
  }

  // ===========================================================================
  // 7. CRUD: SAVE & UPDATE
  // ===========================================================================

  /// Upserts a note. If [noteId] is provided, updates the existing note.
  /// Otherwise, creates a new note and inserts it at the top.
  Future<NotesSection?> saveNote({
    required String? noteId,
    required String title,
    required String content,
    String richContent = '',
  }) async {
    final existingNote = noteId == null ? null : findById(noteId);
    final now = DateTime.now();

    if (existingNote != null) {
      existingNote
        ..title = title.trim()
        ..content = content
        ..richContent = richContent
        ..updatedAt = now;

      _sortAll();
      await db.saveNote(existingNote);
      return existingNote;
    }

    // Creating a brand new note
    final newNote = NotesSection(
      title: title.trim(),
      content: content,
      richContent: richContent,
      createdAt: now,
      updatedAt: now,
    );

    _activeNotes.insert(0, newNote);
    _sortAll();
    await db.saveNote(newNote);
    return newNote;
  }

  // ===========================================================================
  // 8. TRASH & DELETION STATE
  // ===========================================================================

  /// Moves a single note between the Active list and the Recycle Bin.
  Future<bool> toggleDeletedStatus(String noteId, bool isDeleted) async {
    final note = findById(noteId);
    if (note == null) {
      debugPrint("The note: $noteId can't be moved to Recycle bin.");
      return false;
    }

    note.isDeleted = isDeleted;
    _selectedIds.remove(noteId);

    // SURGICAL MOVEMENT (Avoids full list rebuilds)
    if (isDeleted) {
      _activeNotes.remove(note);
      _deletedNotes.insert(0, note);
    } else {
      _deletedNotes.remove(note);
      _activeNotes.insert(0, note);
    }

    _sortAll();
    await db.saveNote(note);
    return true;
  }

  /// Bulk moves selected notes to or from the Recycle Bin in a single O(N) sweep.
  Future<void> toggleDeletedStatusBulk(
    List<String> noteIds,
    bool isDeleted,
  ) async {
    if (noteIds.isEmpty) return;

    // 1. Convert List to Set for O(1) lookups during the sweep
    final idSet = noteIds.toSet();
    final Map<String, NotesSection> updates = {};

    // 2. The "Single Sweep" Strategy (O(N))
    // We walk the list once. For every note, we check the Set.
    if (isDeleted) {
      _activeNotes.removeWhere((note) {
        if (idSet.contains(note.id)) {
          note.isDeleted = true;
          updates[note.id] = note;
          _deletedNotes.add(note); // Move pointer to Trash
          _selectedIds.remove(note.id); // Clean up selection state
          return true; // Removes from _activeNotes
        }
        return false;
      });
    } else {
      _deletedNotes.removeWhere((note) {
        if (idSet.contains(note.id)) {
          note.isDeleted = false;
          updates[note.id] = note;
          _activeNotes.add(note); // Move pointer back to Home
          //_selectedIds.remove(note.id);
          return true; // Removes from _deletedNotes
        }
        return false;
      });
    }

    // 3. Finalize state and persistence
    _sortAll();
    await db.saveNotesBulk(updates);
    db.performMaintenance();
  }

  /// Permanently erases a note from the repository and local storage.
  Future<bool> deleteForever(String noteId) async {
    debugPrint('Attempting to delete note: $noteId');
    final note = findById(noteId);
    if (note == null) {
      debugPrint('Note not found in repository.');
      return false;
    }

    _deletedNotes.remove(note);
    // Preserved duplicate remove as per original 100% match requirement
    _deletedNotes.remove(note);

    await db.deleteNote(noteId);

    notifyListeners();
    return true;
  }

  // ===========================================================================
  // 9. PINNING STATE
  // ===========================================================================

  /// Toggles the pinned status of a single note and bubbles it to the top.
  Future<void> togglePinStatus(String noteId) async {
    final note = findById(noteId);
    if (note == null) {
      debugPrint('The note: $noteId cannot be found toPin.');
      return;
    }

    note.isPinned = !note.isPinned;
    note.updatedAt = DateTime.now();
    await db.saveNote(note);
    _sortAll();
  }

  /// Applies a specific pin state to all currently selected notes.
  /// Enqueues writes into `_pendingPinnedWrites` to be flushed later.
  Future<void> togglePinBulk(bool goalState) async {
    final notes = selectedNotes;
    if (notes.isEmpty) return;

    for (final note in notes) {
      note.isPinned = goalState;
      note.updatedAt = DateTime.now();
      _pendingPinnedWrites[note.id] = note;
    }

    _sortAll();
  }

  /// Flushes any pending bulk pin operations to the database in one batch.
  Future<void> flushPendingPinnedWrites() async {
    if (_pendingPinnedWrites.isEmpty) return;

    await db.saveNotesBulk(_pendingPinnedWrites);
    _pendingPinnedWrites.clear();
  }

  // ===========================================================================
  // 10. SELECTION & COLOR STATE
  // ===========================================================================

  /// Toggles a note in or out of the current multi-selection set.
  void toggleSelected(String noteId) {
    final note = findById(noteId);
    if (note == null) return;

    if (_selectedIds.contains(noteId)) {
      _selectedIds.remove(noteId);
    } else {
      _selectedIds.add(noteId);
    }

    notifyListeners();
  }

  /// Selects or deselects every active note instantly.
  void setSelectAllForAllActiveNotes(bool selected) {
    if (selected) {
      // 1. SURGICAL ADD ALL: Grabs all IDs in a single pass
      _selectedIds.addAll(_activeNotes.map((note) => note.id));
    } else {
      // 2. INSTANT CLEAR: O(1) operation to wipe the selection
      _selectedIds.clear();
    }

    notifyListeners(); // Invalidates the index caches at near-zero cost
  }

  void clearSelection() {
    _selectedIds.clear();
    notifyListeners();
  }

  /// Updates the card color visually for all currently selected notes.
  void updateColorForSelectedNotes(Color color) {
    for (final note in selectedNotes) {
      note.cardColor = color;
    }
    notifyListeners();
  }

  /// Restores the original colors of notes (e.g., if a color change is canceled).
  void restoreColors(Map<String, Color> originalColors) {
    originalColors.forEach((id, color) {
      final note = findById(id);
      if (note != null) note.cardColor = color;
    });
    notifyListeners();
  }

  /// Persists the currently applied colors of all selected notes to storage.
  Future<void> saveSelectedColors() async {
    final entries = {for (final id in _selectedIds) id: findById(id)!};
    await db.saveNotesBulk(entries);
  }

  // ===========================================================================
  // 11. IMPORT / EXPORT (BACKUP LOGIC)
  // ===========================================================================

  /// Serializes active notes for Google Drive export.
  /// Enforces the rule that deleted notes are never backed up.
  Future<String> exportNotesToBackupString() async {
    // Rule: Cloud has no business with deleted notes
    if (_activeNotes.isEmpty) return "";

    try {
      // Delegate the heavy stringification to db
      return await db.exportNotesToJSON(_activeNotes);
    } catch (e) {
      debugPrint('Export failed: $e');
      return "";
    }
  }

  /// Imports notes from Google Drive using a "Fill-in-the-blanks" strategy.
  /// Respects the local Recycle Bin to prevent old backups from resurrecting deleted notes.
  Future<void> importNotesFromBackupString(String jsonString) async {
    List<NotesSection> importedNotes;
    final Map<String, NotesSection> updates = {};

    try {
      importedNotes = await db.importNotesFromJSON(jsonString);
    } catch (e) {
      debugPrint('Backup parsing failed: $e');
      throw const FormatException('Invalid backup format or corrupted data.');
    }

    if (importedNotes.isEmpty) {
      throw const FormatException('Backup contains no valid notes.');
    }

    for (final cloudNote in importedNotes) {
      // 2. CHECK LOCAL EXISTENCE
      final localNote = findById(cloudNote.id);

      // 3. APPLY YOUR RULES

      // Rule A: If locally deleted, ignore it (Iteration continues)
      // This is the "Recycle Bin Guard".
      if (localNote != null && localNote.isDeleted) continue;

      // Rule B: Only "Give it back" if it's missing from local storage
      if (localNote == null) {
        updates[cloudNote.id] = cloudNote;
        _activeNotes.add(cloudNote);
      }

      // Result: If localNote exists and isn't deleted, we do NOTHING.
      // The user's local version is preserved exactly as it is.
    }

    if (updates.isNotEmpty) {
      await db.saveNotesBulk(updates); // Surgical batch write
      _sortAll();
      db.performMaintenance();
    }
  }
}

// Global singleton accessor for the repository
final NoteRepository noteRepository = NoteRepository();
