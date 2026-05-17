import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:notepad/core/constants/animation_constants.dart';
import 'package:notepad/features/note/note_constants.dart';
import 'package:notepad/core/constants/ui_constants.dart';
import 'package:notepad/features/note/services/note_document_service.dart';
import 'package:notepad/features/note/widgets/save_indicator.dart';
import 'package:notepad/core/services/context_extensions.dart';

/// AppBar for NotePage
///
/// RESPONSIBILITIES:
/// - Display title
/// - Provide edit mode toggle
/// - Expose undo/redo actions
///
/// DESIGN:
/// - Stateless (no internal state)
/// - Does NOT depend on editor/controller directly
/// - Uses callbacks → keeps separation clean
class NoteAppBar extends StatefulWidget implements PreferredSizeWidget {
  const NoteAppBar({
    super.key,
    required this.saveState,
    required this.contentController,
    required this.title,
    required this.isDark,
    required this.readOnly,
  });

  final ValueNotifier<SaveState> saveState;
  final QuillController contentController;
  final TextEditingController title;
  final bool isDark;
  final bool readOnly;

  @override
  State<NoteAppBar> createState() => _NoteAppBarState();

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

class _NoteAppBarState extends State<NoteAppBar> {
  late final ValueNotifier<bool> isSavingNotifier;
  Color get iconColor =>
      widget.isDark ? Colors.white : context.colorScheme.onSurfaceVariant;

  @override
  void initState() {
    super.initState();
    isSavingNotifier = ValueNotifier(false);
  }

  @override
  void dispose() {
    super.dispose();
    isSavingNotifier.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppBar(
      surfaceTintColor: Colors.transparent,
      backgroundColor: widget.isDark
          ? NoteConstants.appBarBackgroundDark
          : NoteConstants.appBarBackgroundLight,

      actions: [
        /// SAVE INDICATOR (isolated, efficient)
        if (!widget.readOnly) ...[
          Padding(
            padding: const EdgeInsets.only(right: NoteConstants.appBarRightPadding),
            child: SaveIndicator(saveState: widget.saveState),
          ),
          ListenableBuilder(
            listenable: widget.contentController,
            builder: (context, child) {
              final bool hasRedo = widget.contentController.hasRedo;
              final bool hasUndo = widget.contentController.hasUndo;

              return Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.undo),
                    onPressed: hasUndo
                        ? () => widget.contentController.undo()
                        : null,
                    color: hasUndo ? iconColor : Colors.grey, // Reactive color
                  ),
                  IconButton(
                    icon: const Icon(Icons.redo),
                    onPressed: hasRedo
                        ? () => widget.contentController.redo()
                        : null,
                    color: hasRedo ? iconColor : Colors.grey, // Reactive color
                  ),
                ],
              );
            },
          ),
          MenuAnchor(
            alignmentOffset: const Offset(0, NoteConstants.appBarMenuOffsetY),
            builder: (context, menuController, child) {
              return IconButton(
                icon: Icon(
                  Icons.more_vert,
                  color: widget.isDark ? Colors.white : Colors.blue,
                ),
                onPressed: () => menuController.isOpen
                    ? menuController.close()
                    : menuController.open(),
              );
            },
            menuChildren: [
              MenuItemButton(
                child: Text('Save as PDF', style: TextStyle(color: iconColor)),
                onPressed: () async {
                  final isNotEmpty =
                      widget.title.text.isNotEmpty &&
                      widget.contentController.document
                          .toPlainText()
                          .isNotEmpty;

                  if (isNotEmpty) {
                    isSavingNotifier.value = true;
                    try {
                      final richData = widget.contentController.document
                          .toDelta()
                          .toJson();

                      await NoteDocumentService.saveNoteAsPdf(
                        title: widget.title.text,
                        richContent: richData,
                      );
                    } catch (e) {
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                        duration: AnimationConstants.snackbarShort,
                          content: Text('Could not export PDF: $e'),
                        ),
                      );
                    } finally {
                      isSavingNotifier.value = false;
                    }
                  }
                },
              ),
              MenuItemButton(
                child: Text('Share Note', style: TextStyle(color: iconColor)),
                onPressed: () async {
                  final isNotEmpty =
                      widget.title.text.isNotEmpty &&
                      widget.contentController.document
                          .toPlainText()
                          .isNotEmpty;

                  if (isNotEmpty) {
                    isSavingNotifier.value = true;
                    try {
                      final richData = widget.contentController.document
                          .toDelta()
                          .toJson();

                      await NoteDocumentService.shareSingleNoteAsPdf(
                        title: widget.title.text,
                        richContent: richData,
                      );
                    } catch (e) {
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                        duration: AnimationConstants.snackbarShort,
                          content: Text('Could not export PDF: $e'),
                        ),
                      );
                    } finally {
                      isSavingNotifier.value = false;
                    }
                  }
                },
              ),
            ],
          ),
        ],
      ],

      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(NoteConstants.progressBarHeight),
        child: ValueListenableBuilder(
          valueListenable: isSavingNotifier,
          builder: (_, isSaving, _) {
            if (!isSaving) {
              return const SizedBox(height: NoteConstants.progressBarHeight);
            }

            return LinearProgressIndicator(
              minHeight: UIConstants.progressBarHeight,
              backgroundColor: context.colorScheme.primary.withValues(
                alpha: NoteConstants.progressBarBackgroundAlpha,
              ),
              valueColor: AlwaysStoppedAnimation<Color>(
                context.colorScheme.primary,
              ),
            );
          },
        ),
      ),
    );
  }
}
