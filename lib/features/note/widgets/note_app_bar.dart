import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:notepad/core/constants/ui_constants.dart';
import 'package:notepad/core/theme/app_colors.dart';
import 'package:notepad/features/note/services/note_document_service.dart';
import 'package:notepad/features/note/widgets/save_indicator.dart';

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
  });

  final ValueNotifier<SaveState> saveState;
  final QuillController contentController;
  final TextEditingController title;
  final bool isDark;

  @override
  State<NoteAppBar> createState() => _NoteAppBarState();

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

class _NoteAppBarState extends State<NoteAppBar> {
  late final ValueNotifier<bool> isSavingNotifier;
  ColorScheme get colorScheme => Theme.of(context).colorScheme;
  Color get iconColor =>
      widget.isDark ? Colors.white : colorScheme.onSurfaceVariant;

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
      backgroundColor: widget.isDark
          ? const Color(0xFF1A1A1A)
          : const Color(0xFFF8FAFC),
      actions: [
        /// SAVE INDICATOR (isolated, efficient)
        Padding(
          padding: const EdgeInsets.only(right: UIConstants.paddingSM),
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
          alignmentOffset: const Offset(0, 8),
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
                    widget.contentController.document.toPlainText().isNotEmpty;

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
                        duration: UIConstants.snackbarShort,
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
                    widget.contentController.document.toPlainText().isNotEmpty;

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
                        duration: UIConstants.snackbarShort,
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
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(UIConstants.progressBarHeight),
        child: ValueListenableBuilder(
          valueListenable: isSavingNotifier,
          builder: (_, isSaving, _) {
            if (!isSaving) {
              return const SizedBox(height: UIConstants.progressBarHeight);
            }

            return LinearProgressIndicator(
              minHeight: UIConstants.progressBarHeight,
              backgroundColor: colorScheme.primary.withValues(alpha: 0.6),
              valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
            );
          },
        ),
      ),
    );
  }
}
