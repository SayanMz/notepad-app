import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:lottie/lottie.dart';
import 'package:notepad/core/constants/ui_constants.dart';
import 'package:notepad/core/theme/app_colors.dart';
import 'package:notepad/features/note/data/note_repository.dart';
import 'package:notepad/features/note/services/note_document_service.dart';
import 'package:notepad/features/note/controllers/note_controller.dart';
import 'package:notepad/features/note/widgets/note_app_bar.dart';
import 'package:notepad/features/note/widgets/note_editor.dart';
import 'package:notepad/features/note/widgets/note_header.dart';
import 'package:notepad/features/note/widgets/note_toolbar.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:notepad/core/services/ui_notifier.dart';

/// ---------------------------------------------------------------------------
/// NOTE PAGE (EDITOR SCREEN)
/// ---------------------------------------------------------------------------
///
/// ROLE IN ARCHITECTURE:
/// - Core feature screen for creating & editing notes
/// - Integrates:
///     • Rich text editor (flutter_quill)
///     • Persistence layer (NoteRepository)
///     • Recovery system
///     • Controller abstraction (NoteController)
///
/// RESPONSIBILITIES:
/// - Initialize editor state (new / existing / recovered note)
/// - Handle user input (title + content)
/// - Delegate saving & debouncing to controller
/// - Manage editor lifecycle and focus
///
/// DESIGN PRINCIPLES:
/// - UI delegates logic → NoteController
/// - Editor state is reactive via controllers
/// - Lifecycle-aware saving (AppLifecycleListener)
///
/// INTERVIEW NOTE:
/// This is the most complex screen — demonstrates state handling,
/// editor integration, and lifecycle awareness.
class NotePage extends StatefulWidget {
  final String title, content;
  final String? noteId;

  /// Supports:
  /// - Creating new notes
  /// - Editing existing notes (via noteId)
  /// - Restoring unsaved drafts (title/content)
  const NotePage({super.key, this.noteId, this.title = '', this.content = ''});

  @override
  State<NotePage> createState() => _NotePageState();
}

class _NotePageState extends State<NotePage>
    with SingleTickerProviderStateMixin {
  late AnimationController _lottieController;

  final stt.SpeechToText _speech = stt.SpeechToText();
  Timer? _speechTimer;
  bool _isListening = false;
  String _lastWords = '';

  final FlutterTts _tts = FlutterTts();
  final Random _random = Random();

  // Blending professional efficiency with an encouraging, conversational tone
  final List<String> _successPhrases = [
    "Awesome! Here it is.",
    "All set, there you go!",
    "That's cool, let me handle it.",
    "You have great artistic instincts! Done.",
    "Looking good! Formatting applied.",
    "Consider it done!",
    "Perfect, applying that right now.",
    "Got it! Your changes are live.",
  ];

  final List<String> _failurePhrases = [
    "Sorry, I couldn't find that word in the text.",
    "I don't support that specific feature just yet!",
    "Oops, I didn't quite catch that. Could you rephrase?",
    "Hmm, I couldn't find a match for that command.",
    "Sorry! I didn't understand. Let's try again.",
  ];

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

  /// UI-only state → toggles toolbar visibility
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
    try {
      await _speech.initialize(debugLogging: true);
      List<dynamic> voices = await _tts.getVoices;

      // 1. The Priority List (Deepest & most professional voices first)
      final preferredVoices = [
        'en-us-x-iom-network', // Deepest US Male (Closest to ChatGPT Cove)
        'en-us-x-sfg-network', // Standard US Male
        'en-gb-x-rjs-network', // Professional UK Male
        'en-in-x-ene-network', // Regional Indian Male (Safeguard)
      ];

      Map<String, String>? selectedVoice;

      // 2. Safe iteration avoids Dart's null-safety crashes
      for (String preferredName in preferredVoices) {
        for (var v in voices) {
          final voiceName = v['name'].toString().trim().toLowerCase();

          if (voiceName == preferredName) {
            // Explicitly cast to String to prevent platform channel errors
            selectedVoice = {
              "name": v['name'].toString(),
              "locale": v['locale'].toString(),
            };
            break;
          }
        }
        if (selectedVoice != null) {
          break; // Stop searching once the highest priority is found
        }
      }

      // 3. Apply the Voice
      if (selectedVoice != null) {
        await _tts.setVoice(selectedVoice);
        debugPrint("SUCCESS: Forced Voice to -> ${selectedVoice['name']}");
      } else {
        // Fallback if offline
        debugPrint("FAILED: Network voices missing. Trying local default.");
        await _tts.setLanguage("en-US");
      }

      // 4. Tone Tuning (ChatGPT Professional Vibe)
      await _tts.setSpeechRate(0.45); // Calm pacing
      await _tts.setPitch(0.85); // Deepens the tone
      await _tts.setVolume(1.0);
    } catch (e) {
      debugPrint("Speech init error: $e");
    }
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
        final phrase = _successPhrases[_random.nextInt(_successPhrases.length)];
        await _tts.speak(phrase);
        // FAILURE CASE
      } else if (feedback == 'No matches found.') {
        // Option: Neutral haptic here if desired
        HapticFeedback.selectionClick();

        final phrase = _failurePhrases[_random.nextInt(_failurePhrases.length)];
        await _tts.speak(phrase);
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

    _lottieController = AnimationController(vsync: this);
    _initSpeech();

    // -----------------------------------------------------------------------
    // 1. CONTROLLER INITIALIZATION
    // -----------------------------------------------------------------------
    _noteController = NoteController(
      noteRepository: noteRepository,
      noteId: widget.noteId,
    );
    // -----------------------------------------------------------------------
    // 2. LOAD NOTE DATA
    // -----------------------------------------------------------------------

    final note = widget.noteId == null
        ? null
        : noteRepository.findById(widget.noteId!);

    /// Initialize title
    titleController = TextEditingController(text: note?.title ?? widget.title);

    /// Initialize content controller
    if (note != null) {
      /// Existing note → decode rich content
      contentController = QuillController(
        document: Document.fromJson(
          NoteDocumentService.decodeRichContent(note.richContent, note.content),
        ),
        selection: const TextSelection.collapsed(offset: 0),
        keepStyleOnNewLine: false,
      );
    } else if (widget.content.isNotEmpty) {
      /// Recovered draft
      final recoveredDoc = Document()..insert(0, widget.content);

      contentController = QuillController(
        document: recoveredDoc,
        selection: const TextSelection.collapsed(offset: 0),
        keepStyleOnNewLine: false,
      );
    } else {
      /// New note
      contentController = QuillController(
        document: Document(),
        selection: const TextSelection.collapsed(offset: 0),
        keepStyleOnNewLine: false,
      );
    }

    // -----------------------------------------------------------------------
    // 3. LISTENERS
    // -----------------------------------------------------------------------

    /// Detect changes in title/content
    titleController.addListener(_handleEditorChanged);
    contentController.addListener(_handleEditorChanged);

    /// Lifecycle-based auto-save
    _lifecycleListener = AppLifecycleListener(
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

    /// Initial snapshot for change detection
    lastEditorSignature = currentSignature;
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
    // 1. Prevent double-tapping
    if (_isHandlingBackNavigation) return;
    _isHandlingBackNavigation = true;

    if (hasChanges) {
      _noteController.saveAndCleanupOnClose(
        title: titleController.text,
        document: contentController.document,
      );
      // Navigator.of(context).pop(true);
      // return;
    }

    // 3. Just leave the screen.
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
          child: NoteAppBar(
            saveState: _noteController.saveState,
            contentController: contentController,
            title: titleController,
            isDark: isDark,
          ),
        ),

        // -------------------------------------------------------------------
        // BODY
        // -------------------------------------------------------------------
        body: SafeArea(
          child: Column(
            children: [
              // -------------------------------------------------------------
              // TOOLBAR (FORMATTING)
              // -------------------------------------------------------------
              const SizedBox(height: UIConstants.paddingSM),

              // -------------------------------------------------------------
              // HEADER (TITLE)
              // -------------------------------------------------------------
              NoteHeader(
                titleController: titleController,
                onToggleEdit: _toggleEditMode,
                isEditing: _isEditing,
                noteController: _noteController,
                lottieController: _lottieController,
                isListening: _isListening,
                toggleListening: _toggleListening,
              ),

              const SizedBox(height: UIConstants.paddingMD),

              // -------------------------------------------------------------
              // EDITOR
              // -------------------------------------------------------------
              Expanded(
                child: PlainPasteWrapper(
                  controller: contentController,

                  /// Custom editor widget
                  child: NoteEditor(
                    controller: contentController,
                    focusNode: _editorFocusNode,
                    scrollController: _editorScrollController,
                  ),
                ),
              ),

              // Replace AnimatedSize with AnimatedSwitcher
              AnimatedSwitcher(
                // Snappy entrance, slightly faster exit to get out of the user's way
                duration: const Duration(milliseconds: 250),
                reverseDuration: const Duration(milliseconds: 200),
                // Decelerates smoothly on the way in, accelerates on the way out
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                transitionBuilder: (child, animation) {
                  // 1. Hardware-accelerated slide from the bottom
                  final slideAnimation = Tween<Offset>(
                    begin: const Offset(0.0, 0.5), // Starts 50% lower
                    end: Offset.zero,
                  ).animate(animation);

                  // 2. Hardware-accelerated opacity fade
                  return FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: slideAnimation,
                      child: child,
                    ),
                  );
                },
                child: _isEditing
                    ? Container(
                        // CRITICAL: AnimatedSwitcher requires a Key to know when widgets change
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
              ), // AnimatedSwitcher
            ],
          ),
        ),
        // floatingActionButton: ValueListenableBuilder<bool>(
        //   valueListenable: _noteController.isProcessingVoice,
        //   builder: (context, isProcessing, _) {
        //     if (isProcessing) {
        //       _lottieController.repeat();
        //     } else {
        //       _lottieController.stop();
        //       _lottieController.reset();
        //     }
        //     return GestureDetector(
        //       onTap: isProcessing ? null : _toggleListening,

        //       child: Lottie.asset(
        //         controller: _lottieController,
        //         'assets/lotties/Ai_Robot.json',
        //         onLoaded: (composition) {
        //           _lottieController.duration = composition.duration;
        //         },
        //         height: 80,
        //         width: 80,
        //       ),
        //     );
        //   },
        // ),
        floatingActionButton: ValueListenableBuilder<bool>(
          valueListenable: _noteController.isProcessingVoice,
          builder: (context, isProcessing, _) {
            // Animation Trigger
            if (isProcessing) {
              if (!_lottieController.isAnimating) _lottieController.repeat();
            } else {
              _lottieController.stop();
              _lottieController.reset();
            }

            return GestureDetector(
              // Allow tapping to stop listening, but lock during AI thinking
              onTap: (isProcessing && !_isListening) ? null : _toggleListening,
              child: Lottie.asset(
                'assets/lotties/Ai_Assistant.json',
                controller: _lottieController,
                onLoaded: (composition) {
                  _lottieController.duration = composition.duration;
                },
                height: 80,
                width: 80,
              ),
            );
          },
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      ),
    );
  }
}

/// ---------------------------------------------------------------------------
/// PLAIN PASTE WRAPPER
/// ---------------------------------------------------------------------------
///
/// PURPOSE:
/// - Overrides default paste behavior
/// - Ensures only plain text is pasted (no formatting - from websites)
///
/// BENEFIT:
/// - Prevents unwanted styles from external sources
class PlainPasteIntent extends Intent {
  const PlainPasteIntent();
}

class PlainPasteWrapper extends StatelessWidget {
  final Widget child;
  final QuillController controller;

  const PlainPasteWrapper({
    super.key,
    required this.child,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return Shortcuts(
      shortcuts: const {
        SingleActivator(LogicalKeyboardKey.keyV, control: true):
            PlainPasteIntent(),
      },
      child: Actions(
        actions: {
          PlainPasteIntent: CallbackAction<PlainPasteIntent>(
            onInvoke: (_) async {
              final data = await Clipboard.getData(Clipboard.kTextPlain);

              if (data?.text != null) {
                final index = controller.selection.baseOffset;

                final length = controller.selection.extentOffset - index;

                controller.replaceText(index, length, data!.text!, null);
              }
              return null;
            },
          ),
        },
        child: child,
      ),
    );
  }
}

/*
🧠 INTERVIEW GOLD ANSWER

“I centralized all persistence triggers inside the controller to ensure consistent behavior and 
make the UI fully declarative.”
*/
