import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:notepad/core/constants/ui_constants.dart';
import 'package:notepad/core/data/app_data.dart';
import 'package:notepad/core/data/notes_repository.dart';
import 'package:notepad/core/services/scaffold_messenger_notifier.dart';
import 'package:notepad/core/theme/app_colors.dart';
import 'package:notepad/features/note/controllers/note_controller.dart';
import 'package:notepad/features/note/services/note_document_service.dart';
import 'package:notepad/features/note/services/voice_ai/groq_service.dart';
import 'package:notepad/features/note/widgets/note_app_bar.dart';
import 'package:notepad/features/note/widgets/note_editor.dart';
import 'package:notepad/features/note/widgets/note_header.dart';
import 'package:notepad/features/note/widgets/note_toolbar.dart';
import 'package:notepad/features/note/widgets/plain_paste_wrapper.dart';
import 'package:notepad/features/note/widgets/voice_assistant_button.dart';

/// Note editor screen.
/// Keeps note orchestration in one place while delegates saving, voice input,
/// and formatting to smaller helpers.

class NotePage extends StatefulWidget {
  final String title, content;
  final String? noteId;
  final bool readOnly;

  /// Supports:
  /// - Creating new notes
  /// - Editing existing notes (via noteId)
  /// - Restoring unsaved drafts (title/content)
  const NotePage({
    super.key,
    this.noteId,
    this.title = '',
    this.content = '',
    this.readOnly = false,
  });

  @override
  State<NotePage> createState() => _NotePageState();
}

class _NotePageState extends State<NotePage>
    with SingleTickerProviderStateMixin {
  late bool _isReadOnly;
  late AnimationController _lottieController;

  /// Listens to app lifecycle (background, pause, etc.)
  late final AppLifecycleListener _lifecycleListener;

  /// Controller layer handling business logic
  late final NoteController _noteController;

  /// Title input controller
  late final TextEditingController titleController;

  /// Rich text editor controller (flutter_quill)
  late final QuillController contentController;

  /// Focus control for editor
  final FocusNode _editorFocusNode = FocusNode();

  /// Scroll control for editor
  final ScrollController _editorScrollController = ScrollController();

  //For Overlay lifecycle orchestration
  late final NoteToolbarController _toolbarController;

  /// UI-only state that toggles toolbar visibility
  final ValueNotifier<bool> _isEditingNotifier = ValueNotifier<bool>(false);
  bool _shouldNudge = true; //Track the Nudge
  bool _isHandlingBackNavigation = false;

  @override
  void initState() {
    super.initState();
    _isReadOnly = widget.readOnly;

    _noteController = NoteController(
      noteRepository: noteRepository,
      noteId: widget.noteId,
    );

    _initializeControllers();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_isReadOnly) {
        _editorFocusNode.requestFocus();
      }
      unawaited(
        GroqService.warmUp().catchError(
          (e) => debugPrint('AI Warmup skip: $e'),
        ),
      );
    });

    contentController.readOnly = _isReadOnly;

    _lottieController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    _toolbarController = NoteToolbarController();

    _attachListeners();
    _lifecycleListener = _createLifecycleListener();
  }

  Future<void> _showRestoreDialog() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restore Note'),
        content: const Text('Do you want to restore this note?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Yes'),
          ),
        ],
      ),
    );

    if (result == true && widget.noteId != null) {
      // Toggle the status in the repository
      await noteRepository.toggleDeletedStatus(widget.noteId!, false);
      final note = noteRepository.findById(widget.noteId!);

      setState(() {
        _isReadOnly = false;
        contentController.readOnly = false;
      });

      uiNotifier.showSnackBar(
        SnackBar(content: Text('${note?.title ?? 'Note'} restored!')),
      );
      _editorFocusNode.requestFocus();
    }
  }

  void _initializeControllers() {
    final note = widget.noteId == null
        ? null
        : noteRepository.findById(widget.noteId!);

    titleController = TextEditingController(text: note?.title ?? widget.title);
    contentController = _createContentController(note);

    _noteController.setInitialSignature(
      titleController.text,
      contentController.document,
    );
  }

  QuillController _createContentController(NotesSection? note) {
    if (note != null) {
      return QuillController(
        document: Document.fromJson(
          NoteDocumentService.decodeRichContent(note.richContent, note.content),
        ),
        selection: const TextSelection.collapsed(offset: 0),
        keepStyleOnNewLine: false,
      );
    }

    if (widget.content.isNotEmpty) {
      return QuillController(
        document: Document()..insert(0, widget.content),
        selection: const TextSelection.collapsed(offset: 0),
        keepStyleOnNewLine: false,
      );
    }

    return QuillController(
      document: Document(),
      selection: const TextSelection.collapsed(offset: 0),
      keepStyleOnNewLine: false,
    );
  }

  void _attachListeners() {
    titleController.addListener(_handleEditorChanged);
    contentController.addListener(_handleEditorChanged);
  }

  AppLifecycleListener _createLifecycleListener() {
    return AppLifecycleListener(
      onInactive: () => _noteController.saveNote(
        title: titleController.text,
        document: contentController.document,
      ),
      onPause: () => _noteController.saveNote(
        title: titleController.text,
        document: contentController.document,
      ),
      onDetach: () => _noteController.saveNote(
        title: titleController.text,
        document: contentController.document,
      ),
    );
  }

  /// -------------------------------------------------------------------------
  /// CHANGE HANDLER (AUTO-SAVE TRIGGER)
  /// -------------------------------------------------------------------------
  ///
  /// Delegates:
  /// - Debouncing
  /// - Save timing
  /// to NoteController
  void _handleEditorChanged() {
    _noteController.handleEditorChanged(
      title: titleController.text,
      document: contentController.document,
    );
  }

  /// Toggles editing mode (shows/hides toolbar)
  void _toggleEditMode() {
    _isEditingNotifier.value = !_isEditingNotifier.value;
  }

  @override
  void dispose() {
    /// Remove listeners to prevent memory leaks
    titleController.removeListener(_handleEditorChanged);
    titleController.dispose();

    contentController.removeListener(_handleEditorChanged);
    contentController.dispose();

    _editorFocusNode.dispose();
    _editorScrollController.dispose();

    /// Clean lifecycle + controller
    _lifecycleListener.dispose();
    _noteController.dispose();

    _lottieController.dispose();
    _toolbarController.dispose();

    super.dispose();
  }

  Future<void> _handleBackNavigation() async {
    if (_isHandlingBackNavigation) return;
    _isHandlingBackNavigation = true;

    _toolbarController.closeAllMenus();
    await Future.delayed(const Duration(milliseconds: 16));

    // Use the controller's single source of truth
    if (_noteController.hasPendingChanges(
      titleController.text,
      contentController.document,
    )) {
      _noteController.saveAndCleanupOnClose(
        title: titleController.text,
        document: contentController.document,
      );
    }

    try {
      if (!mounted) return;
      uiNotifier.clearSnackBars();
      Navigator.of(context).pop();
    } finally {
      _isHandlingBackNavigation = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _handleBackNavigation();
      },
      child: IgnorePointer(
        ignoring: _isHandlingBackNavigation,
        child: Scaffold(
          backgroundColor: isDark
              ? AppColors.darkScaffold
              : AppColors.lightScaffold,

          // -------------------------------------------------------------------
          // APP BAR (UNDO / REDO / EDIT TOGGLE)
          // -------------------------------------------------------------------
          appBar: PreferredSize(
            preferredSize: const Size.fromHeight(kToolbarHeight),
            child: _isReadOnly
                ? NoteAppBar(
                    key: const ValueKey('readonly_bar'), // Distinct key 1
                    saveState: _noteController.saveState,
                    contentController: contentController,
                    title: titleController,
                    isDark: isDark,
                    readOnly: true,
                  )
                : NoteAppBar(
                    key: const ValueKey('editable_bar'), // Distinct key 2
                    saveState: _noteController.saveState,
                    contentController: contentController,
                    title: titleController,
                    isDark: isDark,
                    readOnly: false,
                  ),
          ),

          // -------------------------------------------------------------------
          // BODY
          // -------------------------------------------------------------------
          body: SafeArea(
            child: Stack(
              children: [
                // -------------------------------------------------------------
                // MAIN CONTENT LAYER (Header, Editor, Toolbar)
                // -------------------------------------------------------------
                Column(
                  children: [
                    NoteHeader(
                      key: ValueKey('header_$_isReadOnly'),
                      titleController: titleController,
                      onToggleEdit: _toggleEditMode,
                      readOnly: _isReadOnly == true,
                    ),

                    const SizedBox(height: UIConstants.paddingMD), //
                    // note_page.dart
                    Expanded(
                      child: PlainPasteWrapper(
                        controller: contentController,
                        child: _isReadOnly
                            // ---------------------------------------------------------
                            // READ-ONLY MODE (Recycle Bin)
                            // ---------------------------------------------------------
                            ? GestureDetector(
                                onTap: _showRestoreDialog,
                                behavior: HitTestBehavior.opaque,
                                child: SingleChildScrollView(
                                  controller: _editorScrollController,
                                  physics:
                                      const AlwaysScrollableScrollPhysics(),
                                  child: AbsorbPointer(
                                    // Blocks the keyboard and typing
                                    child: NoteEditor(
                                      controller: contentController,
                                      focusNode: _editorFocusNode,
                                      scrollController: _editorScrollController,
                                      // We disable internal scrolling so the parent handles it
                                      scrollable: false,
                                      // We disable expand so it acts like a long static document
                                      expands: false,
                                      showCursor: false,
                                    ),
                                  ),
                                ),
                              )
                            // ---------------------------------------------------------
                            // NORMAL EDITING MODE
                            // ---------------------------------------------------------
                            : NoteEditor(
                                controller: contentController,
                                focusNode: _editorFocusNode,
                                scrollController: _editorScrollController,
                                // Uses the default true/true we set up in the constructor
                              ),
                      ),
                    ),

                    ValueListenableBuilder<bool>(
                      valueListenable: _isEditingNotifier,
                      builder: (context, isEditing, child) {
                        return AnimatedSize(
                          // Smoothly collapses the space when hidden
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeInOut,
                          child: isEditing
                              ? Container(
                                  key: const ValueKey('note_toolbar'),
                                  padding: const EdgeInsets.only(
                                    bottom: UIConstants.paddingSM,
                                  ),
                                  child: NoteToolbar(
                                    controller: contentController,
                                    toolbarController: _toolbarController,
                                    focusNode: _editorFocusNode,
                                    shouldNudge: _shouldNudge,
                                    onNudgeComplete: () {
                                      if (mounted) {
                                        setState(() {
                                          _shouldNudge = false;
                                        });
                                      }
                                    },
                                  ),
                                )
                              : const SizedBox(
                                  key: ValueKey('empty_space'),
                                  width: double.infinity,
                                  height: 0,
                                ),
                        );
                      },
                    ), //
                  ],
                ),
              ],
            ),
          ),

          floatingActionButton: _isReadOnly
              ? null
              : ValueListenableBuilder<bool>(
                  valueListenable: _isEditingNotifier,
                  builder: (context, isEditing, child) {
                    return AnimatedScale(
                      // Swap Effect: Scale to 0 when toolbar is visible
                      scale: isEditing ? 0.0 : 1.0,
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.bounceInOut,
                      child: AnimatedOpacity(
                        opacity: isEditing ? 0.0 : 1.0,
                        duration: const Duration(milliseconds: 200),
                        child: child!,
                      ),
                    );
                  },
                  // Down in your floatingActionButton...
                  child: VoiceAssistantButton(
                    noteController: _noteController,
                    lottieController: _lottieController,
                    isListeningNotifier: _noteController.isListening,
                    aiButtonOpacityNotifier: _noteController.aiButtonOpacity,
                    toggleListening: () {
                      _noteController.toggleListening(contentController);
                    },
                  ),
                ),
        ),
      ),
    );
  }
}
