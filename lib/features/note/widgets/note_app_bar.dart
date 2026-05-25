import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:notepad/core/constants/animation_constants.dart';
import 'package:notepad/core/services/scaffold_messenger_notifier.dart';
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
    isSavingNotifier.dispose();
    super.dispose();
  }

  /// Helper to encapsulate menu logic and avoid repeating the 'isNotEmpty' check
  MenuItemButton _buildPdfMenuItem({
    required String label,
    required Future<void> Function(String, dynamic) action,
  }) {
    return MenuItemButton(
      child: Text(label, style: TextStyle(color: iconColor)),
      onPressed: () async {
        final isEmpty =
            widget.title.text.isEmpty &&
            widget.contentController.document.toPlainText().trim().isEmpty;

        if (isEmpty) return;

        isSavingNotifier.value = true;
        try {
          final richData = widget.contentController.document.toDelta().toJson();
          await action(widget.title.text, richData);
        } catch (e) {
          if (!context.mounted) return;
          showErrorSnackBar(
            duration: AnimationConstants.snackbarShort,
            'Could not export: $e',
          );
        } finally {
          isSavingNotifier.value = false;
        }
      },
    );
  }

  /// Helper to build the undo/redo row
  Widget _buildHistoryControls() {
    return ListenableBuilder(
      listenable: widget.contentController,
      builder: (context, child) {
        final bool hasRedo = widget.contentController.hasRedo;
        final bool hasUndo = widget.contentController.hasUndo;

        return Row(
          children: [
            IconButton(
              icon: const Icon(Icons.undo),
              onPressed: hasUndo ? () => widget.contentController.undo() : null,
              color: hasUndo ? iconColor : Colors.grey,
            ),
            IconButton(
              icon: const Icon(Icons.redo),
              onPressed: hasRedo ? () => widget.contentController.redo() : null,
              color: hasRedo ? iconColor : Colors.grey,
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppBar(
      surfaceTintColor: Colors.transparent,
      backgroundColor: widget.isDark
          ? NoteConstants.appBarBackgroundDark
          : NoteConstants.appBarBackgroundLight,
      actions: [
        if (!widget.readOnly) ...[
          Padding(
            padding: const EdgeInsets.only(
              right: NoteConstants.appBarRightPadding,
            ),
            child: SaveIndicator(saveState: widget.saveState),
          ),
          _buildHistoryControls(),
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
              _buildPdfMenuItem(
                label: 'Save as PDF',
                action: (title, data) => NoteDocumentService.saveNoteAsPdf(
                  title: title,
                  richContent: data,
                ),
              ),
              _buildPdfMenuItem(
                label: 'Share Note',
                action: (title, data) =>
                    NoteDocumentService.shareSingleNoteAsPdf(
                      title: title,
                      richContent: data,
                    ),
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
