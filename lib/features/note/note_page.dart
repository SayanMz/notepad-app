import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:notepad/core/constants/ui_constants.dart';
import 'package:notepad/core/data/app_data.dart';
import 'package:notepad/core/data/notes_repository.dart';
import 'package:notepad/core/services/scaffold_messenger_notifier.dart';
import 'package:notepad/core/theme/app_colors.dart';
import 'package:notepad/features/note/controllers/note_controller.dart';
import 'package:notepad/features/note/services/note_document_service.dart';
import 'package:notepad/features/note/services/voice_ai/groq_service.dart';
import 'package:notepad/features/note/services/voice_ai/note_voice_feedback_service.dart';
import 'package:notepad/features/note/widgets/note_app_bar.dart';
import 'package:notepad/features/note/widgets/note_editor.dart';
import 'package:notepad/features/note/widgets/note_header.dart';
import 'package:notepad/features/note/widgets/note_toolbar.dart';
import 'package:notepad/features/note/widgets/plain_paste_wrapper.dart';
import 'package:notepad/features/note/widgets/voice_assistant_button.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

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

  final stt.SpeechToText _speech = stt.SpeechToText();
  Timer? _speechTimer;
  bool _isListening = false;
  String _lastWords = '';

  final NoteVoiceFeedbackService _voiceFeedback = NoteVoiceFeedbackService();

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

  /// UI-only state that toggles toolbar visibility
  bool _isEditing = false;
  bool _hasNudgedToolbar = false; //Track the Nudge
  bool _isHandlingBackNavigation = false;

  ///Dirty State Tracking
  late String lastEditorSignature;
  String get currentSignature =>
      _editorSignature(titleController.text, contentController.document);
  bool get hasChanges => lastEditorSignature != currentSignature;

  /// --- VOICE AI LOGIC ---

  void _initSpeech() async {
    await _voiceFeedback.initializeSpeech(_speech);
  }

  void _toggleListening() async {
    if (_isListening) {
      _cleanupListening(cancelRobot: true);
      return;
    }

    if (await _speech.initialize()) {
      // UI State: Update once to show we are listening
      setState(() => _isListening = true);
      _noteController.isProcessingVoice.value = true;
      _lastWords = '';

      _speech.listen(
        onResult: (result) {
          // OPTIMIZATION: Update variable directly.
          // Stops the entire editor from rebuilding per word.
          _lastWords = result.recognizedWords;
          debugPrint("LOG: $_lastWords");

          // Windows Stability Debouncer
          _speechTimer?.cancel();
          _speechTimer = Timer(const Duration(milliseconds: 1000), () {
            if (_lastWords.trim().isNotEmpty) {
              _cleanupListening();
              _handleCommand(_lastWords);
            }
          });
        },
      );
    } else {
      _noteController.isProcessingVoice.value = false;
    }
  }

  void _cleanupListening({bool cancelRobot = false}) {
    _speechTimer?.cancel();
    _speech.stop();
    if (mounted) setState(() => _isListening = false);
    if (cancelRobot) _noteController.isProcessingVoice.value = false;
  }

  Future<void> _handleCommand(String command) async {
    // Robot continues to move during the AI thinking phase
    _noteController.isProcessingVoice.value = true;

    // Platform thread safety for Windows
    Future.microtask(() async {
      final feedback = await _noteController.processVoiceCommand(
        commandText: command,
        controller: contentController,
      );

      // AI finished thinking -> Robot stops
      _noteController.isProcessingVoice.value = false;
      // SUCCESS CASE
      if (feedback == 'Formatting applied!') {
        // 1. PHYSICAL FEEDBACK
        HapticFeedback.mediumImpact();

        // 2. SPOKEN FEEDBACK (Randomized)
        await _voiceFeedback.speakSuccess();
        // FAILURE CASE
      } else if (feedback == 'No matches found.') {
        // Option: Neutral haptic here if desired
        HapticFeedback.selectionClick();

        await _voiceFeedback.speakFailure();
        // FATAL ERROR CASE (Keep SnackBar for system/network errors)
      } else if (feedback != null && mounted) {
        // Keep SnackBar only for errors or "No matches found"
        uiNotifier.showSnackBar(SnackBar(content: Text(feedback)));
      }
    });
  }

  @override
  void initState() {
    super.initState();

    GroqService.warmUp().catchError((e) => debugPrint('AI Warmup skip: $e'));

    _lottieController = AnimationController(vsync: this);
    _initSpeech();
    _noteController = NoteController(
      noteRepository: noteRepository,
      noteId: widget.noteId,
    );
    _initializeControllers();
    _isReadOnly = widget.readOnly;
    contentController.readOnly = _isReadOnly;
    if (!_isReadOnly) {
      _editorFocusNode.requestFocus();
    }
    _attachListeners();
    _lifecycleListener = _createLifecycleListener();
    lastEditorSignature = currentSignature;
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

  String _editorSignature(String title, Document document) {
    return '${title.trim()}\n${jsonEncode(document.toDelta().toJson())}';
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
    setState(() => _isEditing = !_isEditing);
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

    super.dispose();
  }

  Future<void> _handleBackNavigation() async {
    if (_isHandlingBackNavigation) return;
    _isHandlingBackNavigation = true;

    if (hasChanges) {
      await _noteController.saveAndCleanupOnClose(
        title: titleController.text,
        document: contentController.document,
      );
    }
    if (!mounted) return;
    Navigator.of(context).pop();
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
            clipBehavior: Clip
                .none, // Allows the Gallery button to fly outside the FAB boundaries
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
                    isEditing: _isEditing,
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
                                physics: const AlwaysScrollableScrollPhysics(),
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

                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    reverseDuration: const Duration(milliseconds: 200),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    transitionBuilder: (child, animation) {
                      return FadeTransition(
                        opacity: animation,
                        child: SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(0.0, 0.5),
                            end: Offset.zero,
                          ).animate(animation),
                          child: child,
                        ),
                      );
                    },
                    child: _isEditing
                        ? Container(
                            key: const ValueKey('note_toolbar'),
                            padding: const EdgeInsets.only(
                              bottom: UIConstants.paddingSM,
                            ),
                            child: NoteToolbar(
                              controller: contentController,
                              focusNode: _editorFocusNode,
                              shouldNudge: !_hasNudgedToolbar,
                              onNudgeComplete: () {
                                if (mounted) {
                                  setState(() => _hasNudgedToolbar = true);
                                }
                              },
                            ),
                          )
                        : const SizedBox.shrink(key: ValueKey('empty_toolbar')),
                  ), //
                ],
              ),
            ],
          ),
        ),
        floatingActionButton: _isReadOnly
            ? null
            : AnimatedPadding(
                // When editing, push the FAB up by 80 pixels to clear the toolbar
                padding: EdgeInsets.only(bottom: _isEditing ? 80.0 : 0.0),
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOutCubic,
                child: VoiceAssistantButton(
                  noteController: _noteController,
                  lottieController: _lottieController,
                  isListening: _isListening,
                  toggleListening: _toggleListening,
                ),
              ),
      ),
    );
  }
}
