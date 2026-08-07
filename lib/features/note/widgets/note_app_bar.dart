import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:notepad/core/constants/animation_constants.dart';
import 'package:notepad/core/extensions/context_extensions.dart';
import 'package:notepad/core/services/ui_management/scaffold_messenger_notifier.dart';
import 'package:notepad/features/note/note_constants.dart';
import 'package:notepad/features/note/services/note_pdf_exporter.dart';
import 'package:notepad/features/note/widgets/status/save_indicator.dart';

// App bar performs note editor actions such as undo/redo, and PDF export/share.
class NoteAppBar extends StatefulWidget implements PreferredSizeWidget {
  const NoteAppBar({
    super.key,
    required this.readOnly,
    required this.title,
    required this.contentController,
    required this.saveState,
  });

  final bool readOnly;
  final TextEditingController title;
  final QuillController contentController;
  final ValueNotifier<SaveState> saveState;

  @override
  State<NoteAppBar> createState() => _NoteAppBarState();

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

class _NoteAppBarState extends State<NoteAppBar> {
  bool get isDark => context.isDark;
  ColorScheme get colorScheme => context.colorScheme;
  late final ValueNotifier<bool> isSavingNotifier;
  Color get iconColor =>
      isDark ? Colors.white : colorScheme.onSurfaceVariant;

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
      backgroundColor: isDark
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
                  color: isDark ? Colors.white : Colors.blue,
                ),
                onPressed: () => menuController.isOpen
                    ? menuController.close()
                    : menuController.open(),
              );
            },
            menuChildren: [
              _buildPdfMenuItem(
                label: 'Save as PDF',
                action: (title, data) => NotePdfExporter.saveNoteAsPdf(
                  title: title,
                  richContent: data,
                ),
              ),
              _buildPdfMenuItem(
                label: 'Share Note',
                action: (title, data) =>
                    NotePdfExporter.shareSingleNoteAsPdf(
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
              minHeight: NoteConstants.progressBarHeight,
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
