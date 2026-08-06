import 'dart:async';

// ignore_for_file: experimental_member_use
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:notepad/core/constants/animation_constants.dart';
import 'package:notepad/core/constants/ui_constants.dart';
import 'package:notepad/core/database/app_data.dart';
import 'package:notepad/core/database/notes_repository.dart';
import 'package:notepad/core/extensions/context_extensions.dart';
import 'package:notepad/core/services/ui_management/scaffold_messenger_notifier.dart';
import 'package:notepad/features/note/controllers/note_data_controller.dart';
import 'package:notepad/features/note/controllers/note_toolbar_controller.dart';
import 'package:notepad/features/note/controllers/note_ui_controller.dart';
import 'package:notepad/features/note/controllers/note_voice_controller.dart';
import 'package:notepad/features/note/note_constants.dart';
import 'package:notepad/features/note/services/document_delta_parser.dart'
    as doc_delta;
import 'package:notepad/features/note/services/voice_ai/groq_service.dart';
import 'package:notepad/features/note/widgets/controls/note_toolbar.dart';
import 'package:notepad/features/note/widgets/controls/voice_assistant_button.dart';
import 'package:notepad/features/note/widgets/note_app_bar.dart';
import 'package:notepad/features/note/widgets/editor/note_editor.dart';
import 'package:notepad/features/note/widgets/editor/note_title_bar.dart';

// The note page owns editor lifecycle, autosave, restore, and AI warmup behavior.
class NotePage extends StatefulWidget {
  final String title, content;
  final String? noteId;
  final bool readOnly;

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
  bool _shouldNudge = true;
  bool _isHandlingBackNavigation = false;

  late final AppLifecycleListener _lifecycleListener;

  final FocusNode _editorFocusNode = FocusNode();

  late final NoteDataController _dataController;
  late final NoteVoiceController _voiceController;
  late final NoteUIController _uiController;
  late final TextEditingController titleController;
  late final NoteToolbarController _toolbarController;
  late final QuillController contentController;
  late AnimationController _lottieController;
  final ScrollController _editorScrollController = ScrollController();

  final ValueNotifier<bool> _isTransitionAnimating = ValueNotifier<bool>(true);

  @override
  void initState() {
    super.initState();
    _isReadOnly = widget.readOnly;

    _initializeControllers();

    // Configure Editor States & Observers
    contentController.readOnly = _isReadOnly;
    _attachListeners();
    _lifecycleListener = _createLifecycleListener();

    // Post-Frame Transitions & Warmup Operations
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      ModalRoute.of(context)?.animation?.addStatusListener((status) async {
        if (status == AnimationStatus.completed) {
          _isTransitionAnimating.value = false;

          await WidgetsBinding.instance.endOfFrame;
          if (!mounted) return;

          final note = widget.noteId == null
              ? null
              : noteRepository.findById(widget.noteId!);

          if (note != null &&
              _editorScrollController.hasClients &&
              note.scrollOffset > 0) {
            final maxExtent = _editorScrollController.position.maxScrollExtent;
            final target = note.scrollOffset > maxExtent
                ? maxExtent
                : note.scrollOffset;

            _editorScrollController.jumpTo(target);
          }

          _dataController.setInitialSignature(
            titleController.text,
            contentController.document,
            _getCurrentScrollOffset(),
          );

          if (widget.noteId == null && _editorFocusNode.canRequestFocus) {
            _editorFocusNode.requestFocus();
          }

          unawaited(
            GroqService.warmUp().catchError(
              (e) => debugPrint('AI Warmup skip: $e'),
            ),
          );
        }
      });
    });
  }

  double _getCurrentScrollOffset() {
    return _editorScrollController.hasClients
        ? _editorScrollController.offset
        : 0.0;
  }

  /// Centralizes the instantiation of all feature, UI, and text editing controllers.
  void _initializeControllers() {
    final note = widget.noteId == null
        ? null
        : noteRepository.findById(widget.noteId!);

    // Feature Controllers
    _dataController = NoteDataController(
      noteRepository: noteRepository,
      noteId: widget.noteId,
    );
    _voiceController = NoteVoiceController();
    _uiController = NoteUIController();
    _toolbarController = NoteToolbarController();

    // Editor & Animation Controllers
    titleController = TextEditingController(text: note?.title ?? widget.title);
    contentController = _createContentController(note);
    _lottieController = AnimationController(
      vsync: this,
      duration: AnimationConstants.snackbarShort,
    );
  }

  QuillController _createContentController(NotesSection? note) {
    final doc = note != null
        ? Document.fromJson(
            doc_delta.decodeRichContent(
              note.richContent,
              note.content,
            ),
          )
        : (widget.content.isNotEmpty
              ? (Document()..insert(0, widget.content))
              : Document());

    return QuillController(
      document: doc,
      selection: const TextSelection.collapsed(offset: 0),
      keepStyleOnNewLine: false,
      config: const QuillControllerConfig(
        clipboardConfig: QuillClipboardConfig(enableExternalRichPaste: true),
      ),
    );
  }

  void _attachListeners() {
    titleController.addListener(() {
      _dataController.handleEditorChanged(
        title: titleController.text,
        document: contentController.document,
        controller: contentController,
        change: null,
      );
    });

    contentController.changes.listen((DocChange change) {
      _dataController.handleEditorChanged(
        title: titleController.text,
        document: contentController.document,
        controller: contentController,
        change: change,
      );
      _uiController.orchestrateButtonVisibility();
    });
  }

  AppLifecycleListener _createLifecycleListener() {
    return AppLifecycleListener(
      onInactive: _triggerBackgroundSave,
      onPause: _triggerBackgroundSave,
      onDetach: _triggerBackgroundSave,
    );
  }

  void _triggerBackgroundSave() {
    _dataController.saveNote(
      title: titleController.text,
      document: contentController.document,
      scrollOffset: _getCurrentScrollOffset(),
    );
  }

  Future<void> _handleBackNavigation() async {
    if (_isHandlingBackNavigation) return;
    _isHandlingBackNavigation = true;

    _voiceController.stopHardwareListening();
    _toolbarController.closeAllMenus();

    SystemChannels.textInput.invokeMethod('TextInput.hide');
    await Future.delayed(const Duration(milliseconds: 50));
    FocusManager.instance.primaryFocus?.unfocus();
    await Future.delayed(const Duration(milliseconds: 250));

    unawaited(
      _dataController
          .saveAndCleanupOnClose(
            title: titleController.text,
            document: contentController.document,
            scrollOffset: _getCurrentScrollOffset(),
          )
          .catchError((e) => debugPrint('Background save error: $e')),
    );

    try {
      if (!mounted) return;
      uiNotifier.clearSnackBars();
      Navigator.of(context).pop();
    } finally {
      _isHandlingBackNavigation = false;
    }
  }

  @override
  void dispose() {
    titleController.dispose();
    contentController.dispose();

    _editorFocusNode.dispose();
    _editorScrollController.dispose();

    _lifecycleListener.dispose();
    _lottieController.dispose();
    _toolbarController.dispose();

    _dataController.dispose();
    _voiceController.dispose();
    _uiController.dispose();

    super.dispose();
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
      await noteRepository.toggleDeletedStatus(widget.noteId!, false);
      final note = noteRepository.findById(widget.noteId!);
      // Restored notes re-enter editable mode immediately so the user can continue typing.
      setState(() {
        _isReadOnly = false;
        contentController.readOnly = false;
      });

      uiNotifier.showSnackBar(
        SnackBar(content: Text('${note?.title ?? 'Note'} restored!')),
      );

      // Keep the micro-delay to let the Quill platform channels bind
      await Future.delayed(Duration.zero);
      if (!mounted) return;

      FocusScope.of(context).requestFocus(_editorFocusNode);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _handleBackNavigation();
      },
      child: IgnorePointer(
        ignoring: _isHandlingBackNavigation,
        child: Scaffold(
          backgroundColor: context.theme.scaffoldBackgroundColor,
          appBar: PreferredSize(
            preferredSize: const Size.fromHeight(kToolbarHeight),
            child: NoteAppBar(
              key: const ValueKey('unified_note_bar'),
              readOnly: _isReadOnly,
              title: titleController,
              contentController: contentController,
              saveState: _dataController.saveState,
            ),
          ),

          body: SafeArea(
            child: ValueListenableBuilder<bool>(
              valueListenable: _isTransitionAnimating,
              builder: (context, isAnimating, child) {
                // This leaves a pure, lightweight Scaffold background to shrink smoothly.
                if (isAnimating) return const SizedBox.shrink();

                return child!;
              },
              child: Stack(
                children: [
                  Column(
                    children: [
                      NoteTitleBar(
                        key: ValueKey('header_$_isReadOnly'),
                        titleController: titleController,
                        onToggleEdit: _uiController.toggleEditMode,
                        readOnly: _isReadOnly == true,
                      ),

                      const SizedBox(height: UIConstants.paddingMD),

                      Expanded(
                        child: NotificationListener<ScrollEndNotification>(
                          // Autosave note scroll offset when editor scrolling comes to a rest.
                          onNotification: (notification) {
                            if (!_isTransitionAnimating.value &&
                                notification.depth == 0) {
                              _dataController.handleScrollEvent(
                                title: titleController.text,
                                document: contentController.document,
                                scrollOffset: notification.metrics.pixels,
                              );
                            }
                            return false;
                          },
                          child: ListenableBuilder(
                            listenable: _editorScrollController,
                            builder: (context, child) {
                              // Checking if the keyboard is open using the direct view insets
                              final double keyboardHeight = View.of(
                                context,
                              ).viewInsets.bottom;
                              final bool isKeyboardOpen = keyboardHeight > 0;

                              final double currentOffset =
                                  _editorScrollController.hasClients
                                  ? _editorScrollController.offset
                                  : 0.0;
                              // Dynamically scales the top edge content fade (0% to 3%) as the user scrolls.
                              final double topFadeStop = currentOffset <= 0.0
                                  ? 0.0
                                  : (currentOffset / 100).clamp(0.0, 0.03);

                              return ShaderMask(
                                shaderCallback: (Rect bounds) {
                                  return LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: const [
                                      Colors.transparent,
                                      Colors.black,
                                      Colors.black,
                                      Colors.transparent,
                                    ],
                                    stops: [0.0, topFadeStop, 0.90, 1.0],
                                  ).createShader(bounds);
                                },
                                blendMode: isKeyboardOpen
                                    ? BlendMode.dst
                                    : BlendMode.dstIn,
                                child: child!,
                              );
                            },
                            child: GestureDetector(
                              onTap: _isReadOnly ? _showRestoreDialog : null,
                              behavior: HitTestBehavior.opaque,
                              child: SingleChildScrollView(
                                controller: _editorScrollController,
                                physics: const AlwaysScrollableScrollPhysics(),
                                child: AbsorbPointer(
                                  // Only freeze interactions if it's read-only
                                  absorbing: _isReadOnly,
                                  child: Column(
                                    children: [
                                      NoteEditor(
                                        controller: contentController,
                                        focusNode: _editorFocusNode,
                                        scrollController:
                                            _editorScrollController,
                                        scrollable: false,
                                        expands: false,
                                        // Cursor hides natively in read-only
                                        showCursor: !_isReadOnly,
                                      ),
                                      Builder(
                                        builder: (context) {
                                          final bool isKeyboardOpen =
                                              View.of(
                                                context,
                                              ).viewInsets.bottom >
                                              0;

                                          return SizedBox(
                                            height: isKeyboardOpen
                                                ? 0
                                                : UIConstants.paddingXL,
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      // INLINED TOOLBAR SECTION
                      ValueListenableBuilder<bool>(
                        valueListenable: _uiController.isEditing,
                        builder: (context, isEditing, child) {
                          return AnimatedSize(
                            duration: NoteConstants.notePageToolbarSizeDelay,
                            curve: Curves.easeInOut,
                            child: isEditing
                                ? Container(
                                    key: const ValueKey('note_toolbar'),
                                    padding: const EdgeInsets.only(
                                      bottom: NoteConstants
                                          .notePageToolbarPaddingBottom,
                                    ),
                                    child: NoteToolbar(
                                      controller: contentController,
                                      toolbarController: _toolbarController,
                                      focusNode: _editorFocusNode,
                                      shouldNudge: _shouldNudge,
                                      onNudgeComplete: () {
                                        if (mounted) {
                                          setState(() => _shouldNudge = false);
                                        }
                                      },
                                    ),
                                  )
                                : const SizedBox(
                                    key: ValueKey('empty_space'),
                                    width: double.infinity,
                                    height: NoteConstants
                                        .notePageReadonlySpacerHeight,
                                  ),
                          );
                        },
                      ),
                    ], // End of Column children
                  ),
                ], // End of Stack children
              ),
            ),
          ),
          floatingActionButton: _isReadOnly
              ? null
              : ValueListenableBuilder<bool>(
                  valueListenable: _uiController.isEditing,
                  builder: (context, isEditing, child) {
                    return AnimatedScale(
                      scale: isEditing ? 0.0 : 1.0,
                      duration: NoteConstants.notePageFabScaleDuration,
                      curve: Curves.bounceInOut,
                      child: AnimatedOpacity(
                        opacity: isEditing ? 0.0 : 1.0,
                        duration: NoteConstants.notePageFabFadeDuration,
                        child: child!,
                      ),
                    );
                  },
                  child: VoiceAssistantButton(
                    lottieController: _lottieController,
                    voiceController: _voiceController,
                    uiController: _uiController,
                    contentController: contentController,
                  ),
                ),
        ), // End of Scaffold
      ),
    );
  }
}
