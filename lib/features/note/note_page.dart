// The note page owns editor lifecycle, autosave, restore, and AI warmup behavior.
import 'dart:async';
// ignore_for_file: experimental_member_use
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:notepad/core/constants/animation_constants.dart';
import 'package:notepad/core/constants/ui_constants.dart';
import 'package:notepad/core/database/app_data.dart';
import 'package:notepad/core/database/notes_repository.dart';
import 'package:notepad/core/extensions/context_extensions.dart';
import 'package:notepad/core/services/ui_management/scaffold_messenger_notifier.dart';
import 'package:notepad/core/theme/app_colors.dart';
import 'package:notepad/features/note/controllers/note_data_controller.dart';
import 'package:notepad/features/note/controllers/note_toolbar_controller.dart';
import 'package:notepad/features/note/controllers/note_ui_controller.dart';
import 'package:notepad/features/note/controllers/note_voice_controller.dart';
import 'package:notepad/features/note/note_constants.dart';
import 'package:notepad/core/services/note_document_service.dart';
import 'package:notepad/features/note/services/voice_ai/groq_service.dart';
import 'package:notepad/features/note/widgets/note_app_bar.dart';
import 'package:notepad/features/note/widgets/note_editor.dart';
import 'package:notepad/features/note/widgets/note_header.dart';
import 'package:notepad/features/note/widgets/note_toolbar.dart';
import 'package:notepad/features/note/widgets/voice_assistant_button.dart';

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
  late AnimationController _lottieController;

  late final AppLifecycleListener _lifecycleListener;

  late final NoteDataController _dataController;
  late final NoteVoiceController _voiceController;
  late final NoteUIController _uiController;

  late final TextEditingController titleController;

  late final QuillController contentController;

  final FocusNode _editorFocusNode = FocusNode();

  final ScrollController _editorScrollController = ScrollController();

  late final NoteToolbarController _toolbarController;

  bool _shouldNudge = true;
  bool _isHandlingBackNavigation = false;

  @override
  void initState() {
    super.initState();
    _isReadOnly = widget.readOnly;

    _dataController = NoteDataController(
      noteRepository: noteRepository,
      noteId: widget.noteId,
    );
    _voiceController = NoteVoiceController();
    _uiController = NoteUIController();

    _initializeControllers();
    contentController.readOnly = _isReadOnly;

    _lottieController = AnimationController(
      vsync: this,
      duration: AnimationConstants.snackbarShort,
    );
    _toolbarController = NoteToolbarController();

    _attachListeners();
    _lifecycleListener = _createLifecycleListener();

    // Warm up the AI service after first paint so editor startup stays responsive.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      if (!_isReadOnly) {
        _editorFocusNode.requestFocus();
      }
      unawaited(
        GroqService.warmUp().catchError(
          (e) => debugPrint('AI Warmup skip: $e'),
        ),
      );
    });
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
      // Restored notes re-enter editable mode immediately so the user can continue typing.
      await noteRepository.toggleDeletedStatus(widget.noteId!, false);
      final note = noteRepository.findById(widget.noteId!);

      setState(() {
        _isReadOnly = false;
        contentController.readOnly = false;
      });

      uiNotifier.showSnackBar(
        SnackBar(content: Text('${note?.title ?? 'Note'} restored!')),
      );

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_editorFocusNode.canRequestFocus) {
          _editorFocusNode.requestFocus();
        }
      });
    }
  }

  void _initializeControllers() {
    final note = widget.noteId == null
        ? null
        : noteRepository.findById(widget.noteId!);

    titleController = TextEditingController(text: note?.title ?? widget.title);
    contentController = _createContentController(note);

    _dataController.setInitialSignature(
      titleController.text,
      contentController.document,
    );
  }

  QuillController _createContentController(NotesSection? note) {
    // Existing notes load from stored rich content; fresh notes start from plain text or empty state.
    if (note != null) {
      return QuillController(
        document: Document.fromJson(
          NoteDocumentService.decodeRichContent(note.richContent, note.content),
        ),
        selection: const TextSelection.collapsed(offset: 0),
        keepStyleOnNewLine: false,
        config: const QuillControllerConfig(
          clipboardConfig: QuillClipboardConfig(enableExternalRichPaste: true),
        ),
      );
    }

    if (widget.content.isNotEmpty) {
      return QuillController(
        document: Document()..insert(0, widget.content),
        selection: const TextSelection.collapsed(offset: 0),
        keepStyleOnNewLine: false,
        config: const QuillControllerConfig(
          clipboardConfig: QuillClipboardConfig(enableExternalRichPaste: true),
        ),
      );
    }

    return QuillController(
      document: Document(),
      selection: const TextSelection.collapsed(offset: 0),
      config: const QuillControllerConfig(
        clipboardConfig: QuillClipboardConfig(enableExternalRichPaste: true),
      ),
      keepStyleOnNewLine: false,
    );
  }

  void _attachListeners() {
    titleController.addListener(_handleEditorChanged);
    contentController.addListener(_handleEditorChanged);
  }

  AppLifecycleListener _createLifecycleListener() {
    return AppLifecycleListener(
      // Persist on lifecycle loss because note edits are expected to survive quick app switches.
      onInactive: () async {
        await _dataController.saveNote(
          title: titleController.text,
          document: contentController.document,
        );
      },
      onPause: () async {
        await _dataController.saveNote(
          title: titleController.text,
          document: contentController.document,
        );
      },
      onDetach: () async {
        await _dataController.saveNote(
          title: titleController.text,
          document: contentController.document,
        );
      },
    );
  }

  void _handleEditorChanged() {
    // Keep the dirty-state and save controls in sync with title or body edits.
    _dataController.handleEditorChanged(
      title: titleController.text,
      document: contentController.document,
    );
    _uiController.orchestrateButtonVisibility();
  }

  @override
  void dispose() {
    titleController.removeListener(_handleEditorChanged);
    titleController.dispose();

    contentController.removeListener(_handleEditorChanged);
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

  Future<void> _handleBackNavigation() async {
    if (_isHandlingBackNavigation) return;
    _isHandlingBackNavigation = true;

    _voiceController.stopHardwareListening();
    _toolbarController.closeAllMenus();
    final isKeyboardOpen = context.viewInsetsBottom > 0;
    await Future.delayed(const Duration(milliseconds: 100));

    if (isKeyboardOpen) {
      FocusManager.instance.primaryFocus?.unfocus();
      await Future.delayed(NoteConstants.notePageKeyboardDismissDelay);
    }

    unawaited(
      _dataController
          .saveAndCleanupOnClose(
            title: titleController.text,
            document: contentController.document,
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
  Widget build(BuildContext context) {
    final isDark = context.isDark;

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
          appBar: PreferredSize(
            preferredSize: const Size.fromHeight(kToolbarHeight),
            child: _isReadOnly
                ? NoteAppBar(
                    key: const ValueKey('readonly_bar'),
                    saveState: _dataController.saveState,
                    contentController: contentController,
                    title: titleController,
                    isDark: isDark,
                    readOnly: true,
                  )
                : NoteAppBar(
                    key: const ValueKey('editable_bar'),
                    saveState: _dataController.saveState,
                    contentController: contentController,
                    title: titleController,
                    isDark: isDark,
                    readOnly: false,
                  ),
          ),

          body: SafeArea(
            child: Stack(
              children: [
                Column(
                  children: [
                    NoteHeader(
                      key: ValueKey('header_$_isReadOnly'),
                      titleController: titleController,
                      onToggleEdit: _uiController.toggleEditMode,
                      readOnly: _isReadOnly == true,
                    ),

                    const SizedBox(height: UIConstants.paddingMD),

                    Expanded(
                      child: _isReadOnly
                          ? GestureDetector(
                              onTap: _showRestoreDialog,
                              behavior: HitTestBehavior.opaque,
                              child: SingleChildScrollView(
                                controller: _editorScrollController,
                                physics: const AlwaysScrollableScrollPhysics(),
                                child: AbsorbPointer(
                                  child: NoteEditor(
                                    controller: contentController,
                                    focusNode: _editorFocusNode,
                                    scrollController: _editorScrollController,
                                    scrollable: false,
                                    expands: false,
                                    showCursor: false,
                                  ),
                                ),
                              ),
                            )
                          : NoteEditor(
                              controller: contentController,
                              focusNode: _editorFocusNode,
                            ),
                    ),

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
                                  height: NoteConstants
                                      .notePageReadonlySpacerHeight,
                                ),
                        );
                      },
                    ),
                  ],
                ),
              ],
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
        ),
      ),
    );
  }
}
