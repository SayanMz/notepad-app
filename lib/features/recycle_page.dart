import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:lottie/lottie.dart';
import 'package:notepad/core/constants/ui_constants.dart';
import 'package:notepad/core/data/app_data.dart';
import 'package:notepad/core/theme/app_colors.dart';
import 'package:notepad/features/note/data/note_repository.dart';
import 'package:notepad/core/services/ui_notifier.dart';
import 'dart:math';

class RecyclePage extends StatefulWidget {
  const RecyclePage({super.key});

  @override
  State<RecyclePage> createState() => _RecyclePageState();
}

class _RecyclePageState extends State<RecyclePage> {
  // NEW: State to control header visibility on scroll
  bool _showHeaders = true;

  /// LOGIC: Handles permanent, irreversible data deletion.
  Future<void> _confirmDeleteForever(NotesSection note) async {
    final navigator = Navigator.of(context);
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete forever?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (shouldDelete != true) {
      return;
    }

    // ARCHITECTURE NOTE: Reactive State.
    noteRepository.deleteForever(note.id);

    if (!mounted) return;
    navigator.pop();
  }

  /// UI: Bottom sheet for secondary actions.
  void _showNoteActionSheet(BuildContext context, NotesSection note) {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(UIConstants.recycleSheetRadius),
        ),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: UIConstants.paddingSM),
            ListTile(
              leading: const Icon(Icons.delete_forever, color: Colors.red),
              title: const Text('Delete forever'),
              onTap: () => _confirmDeleteForever(note),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ListenableBuilder(
      listenable: noteRepository,
      builder: (context, child) {
        final deletedNotes = noteRepository.deletedNotes;

        return Scaffold(
          backgroundColor: isDark
              ? AppColors.darkScaffold
              : AppColors.lightScaffold,
          body: SafeArea(
            child: NotificationListener<UserScrollNotification>(
              onNotification: (notification) {
                // Hide header when scrolling down
                if (notification.direction == ScrollDirection.reverse) {
                  if (_showHeaders) setState(() => _showHeaders = false);
                }
                // Show header when scrolling up
                else if (notification.direction == ScrollDirection.forward) {
                  if (!_showHeaders) setState(() => _showHeaders = true);
                }
                return false;
              },
              child: Column(
                children: [
                  /// ---------------------------------------------------------------
                  /// ANIMATED APP BAR
                  /// ---------------------------------------------------------------
                  AnimatedSize(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeInOut,
                    child: _showHeaders
                        ? AppBar(
                            title: const Text(
                              'Recycle Bin',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            backgroundColor: Colors.transparent,
                            // Requested feature: Remove surface tint when scrolled
                            surfaceTintColor: Colors.transparent,
                            centerTitle: true,
                            elevation: 0,
                            primary: false, // Prevents double SafeArea padding
                          )
                        : const SizedBox(width: double.infinity, height: 0),
                  ),

                  /// ---------------------------------------------------------------
                  /// RECYCLE LIST / EMPTY STATE
                  /// ---------------------------------------------------------------
                  Expanded(
                    child: deletedNotes.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Lottie.asset(
                                  'assets/lotties/Ai_Robot.json',
                                  height: UIConstants.recycleEmptyLottieHeight,
                                ),
                                const Text(
                                  'Trash is empty',
                                  style: TextStyle(
                                    color: Colors.grey,
                                    fontSize:
                                        UIConstants.recycleEmptyTextFontSize,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            // Applies the exact bouncy effect used in HomePage
                            physics: const BouncingScrollPhysics(
                              parent: AlwaysScrollableScrollPhysics(),
                            ),
                            padding: const EdgeInsets.all(
                              UIConstants.recycleListPadding,
                            ),
                            itemCount: deletedNotes.length,
                            itemBuilder: (context, index) {
                              final note = deletedNotes[index];

                              return _SwipeableRestoreItem(
                                note: note,
                                isDark: isDark,
                                onShowActionSheet: _showNoteActionSheet,
                                onRestore: (restoredNote) {
                                  final restoredTitle =
                                      restoredNote.title.isEmpty
                                      ? 'Untitled note'
                                      : restoredNote.title;

                                  noteRepository.restoreNote(restoredNote.id);
                                  if (!mounted) return;

                                  uiNotifier.showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        '$restoredTitle is now restored.',
                                      ),
                                      duration:
                                          UIConstants.saveIndicatorDuration,
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                    autoHideAfter:
                                        UIConstants.saveIndicatorDuration,
                                  );
                                },
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// ---------------------------------------------------------------------------
/// SWIPEABLE RESTORE ITEM (The RTL Physics Engine)
/// ---------------------------------------------------------------------------
class _SwipeableRestoreItem extends StatefulWidget {
  const _SwipeableRestoreItem({
    required this.note,
    required this.isDark,
    required this.onRestore,
    required this.onShowActionSheet,
  });

  final NotesSection note;
  final bool isDark;
  final void Function(NotesSection) onRestore;
  final void Function(BuildContext, NotesSection) onShowActionSheet;

  @override
  State<_SwipeableRestoreItem> createState() => _SwipeableRestoreItemState();
}

class _SwipeableRestoreItemState extends State<_SwipeableRestoreItem> {
  // ISOLATED STATE: Tracks the thumb!
  final ValueNotifier<double> _dragProgress = ValueNotifier<double>(0.0);

  @override
  void dispose() {
    _dragProgress.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(UIConstants.recycleCardMargin),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final cardWidth = constraints.maxWidth;

          return Stack(
            children: [
              // --- THE PERMANENT GREEN BACKGROUND ---
              Positioned(
                top: 0.5,
                bottom: 0.5,
                right: 0.5,
                left: 16,
                child: Card(
                  margin: EdgeInsets.zero,
                  elevation: 0,
                  color: widget.isDark
                      ? const Color(0xFF003D33)
                      : const Color(0xFFC8E6C9),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.horizontal(
                      right: Radius.circular(
                        UIConstants.recycleCardRadius - 1.0,
                      ),
                      left: Radius.zero,
                    ),
                  ),
                  child: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(
                      right: UIConstants.paddingLG,
                    ),
                    child: ValueListenableBuilder<double>(
                      valueListenable: _dragProgress,
                      builder: (context, progress, child) {
                        final draggedPixels = progress * cardWidth;
                        const iconWidth = UIConstants.recycleIconSize;
                        const targetPadding = UIConstants.paddingLG;

                        const lockPoint = (targetPadding * 2) + iconWidth;

                        double xOffset = (lockPoint / 2) - (draggedPixels / 2);
                        xOffset = xOffset.clamp(0.0, double.infinity);

                        final scale = (draggedPixels / lockPoint).clamp(
                          0.5,
                          1.0,
                        );
                        final opacity = (draggedPixels / lockPoint).clamp(
                          0.0,
                          1.0,
                        );

                        final rotationProgress = (draggedPixels / lockPoint)
                            .clamp(0.0, 2.0);

                        final angle = rotationProgress * pi;

                        return Transform.translate(
                          offset: Offset(xOffset, 0),
                          child: Transform.scale(
                            scale: scale,
                            child: Opacity(
                              opacity: opacity,
                              child: Transform.rotate(
                                angle: angle,
                                child: Icon(
                                  Icons.restore,
                                  color: widget.isDark
                                      ? const Color(0xFF69F0AE)
                                      : const Color(0xFF2E7D32),
                                  size: UIConstants.recycleIconSize,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),

              // --- THE SWIPE MASK ---
              Dismissible(
                key: ValueKey('restore_${widget.note.id}'),
                direction: DismissDirection.endToStart,
                background: const ColoredBox(color: Colors.transparent),
                onUpdate: (details) {
                  if (!mounted) return;
                  _dragProgress.value = details.progress;
                },
                onDismissed: (_) => widget.onRestore(widget.note),
                child: Card(
                  margin: EdgeInsets.zero,
                  elevation: UIConstants.elevationLow,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(
                      UIConstants.recycleCardRadius,
                    ),
                  ),
                  child: ListTile(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        UIConstants.recycleCardRadius,
                      ),
                    ),
                    contentPadding: const EdgeInsets.all(
                      UIConstants.recycleCardPadding,
                    ),
                    title: Text(
                      widget.note.title.isEmpty
                          ? 'Untitled note'
                          : widget.note.title,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      widget.note.content.isEmpty
                          ? 'No additional text'
                          : widget.note.content,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: Colors.grey[700]),
                    ),
                    trailing: IconButton(
                      onPressed: () =>
                          widget.onShowActionSheet(context, widget.note),
                      icon: Icon(
                        Icons.more_vert,
                        color: widget.isDark ? Colors.white : Colors.blue,
                      ),
                    ),
                    onLongPress: HapticFeedback.mediumImpact,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
