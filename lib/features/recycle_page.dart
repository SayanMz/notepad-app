import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lottie/lottie.dart';
import 'package:notepad/core/constants/ui_constants.dart';
import 'package:notepad/core/data/app_data.dart';
import 'package:notepad/core/services/scaffold_messenger_notifier.dart';
import 'package:notepad/features/note/data/note_repository.dart';

class RecyclePage extends StatefulWidget {
  const RecyclePage({super.key});

  @override
  State<RecyclePage> createState() => _RecyclePageState();
}

class _RecyclePageState extends State<RecyclePage> {
  Future<void> _restoreNoteWithUndo(NotesSection note) async {
    final restoredTitle = note.displayTitle;

    final isRestored = await noteRepository.restoreNote(note.id);
    if (!mounted && !isRestored) return;

    uiNotifier.showSnackBar(
      SnackBar(
        content: Text('$restoredTitle restored.'),
        duration: UIConstants.saveIndicatorDuration,
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () async {
            await noteRepository.moveToRecycleBinSingle(note.id);
          },
        ),
      ),
      autoHideAfter: UIConstants.saveIndicatorDuration,
    );
  }

  /// LOGIC: Handles permanent, irreversible data deletion.
  Future<void> _confirmDeleteForever(NotesSection note) async {
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
      if (mounted) {
        Navigator.pop(context);
        return;
      }
    }

    // ARCHITECTURE NOTE: Reactive State.
    await noteRepository.deleteForever(note.id);

    if (!mounted) return;
    Navigator.pop(context);
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
    final notesEmptyText = "Your trash is squeaky clean.";

    return ListenableBuilder(
      listenable: noteRepository,
      builder: (context, child) {
        final deletedNotes = noteRepository.deletedNotes;
        final Map<String, int> idToIndex = {
          for (int i = 0; i < deletedNotes.length; i++) deletedNotes[i].id: i,
        };

        return Scaffold(
          body: SafeArea(
            child: deletedNotes.isEmpty
                ? Column(
                    children: [
                      // 1. Static Header (No scrolling logic)
                      SizedBox(
                        height: kToolbarHeight,
                        child: Stack(
                          children: [
                            const Align(
                              alignment: Alignment.centerLeft,
                              child: BackButton(),
                            ),
                            Align(
                              alignment: Alignment.center,
                              child: Text(
                                'Recycle Bin',
                                style: TextStyle(
                                  color: isDark ? Colors.white : Colors.black,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 24,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // 2. Static Content (Centered vertically in remaining space)
                      Expanded(
                        child: _buildEmptyState(context, notesEmptyText),
                      ),
                    ],
                  )
                : CustomScrollView(
                    physics: const BouncingScrollPhysics(
                      parent: AlwaysScrollableScrollPhysics(),
                    ),
                    slivers: [
                      // --- THE COLLAPSING HEADER ---
                      // Inside your RecyclePage build method, replace SliverAppBar with:
                      SliverPersistentHeader(
                        pinned: true,
                        delegate: _SmoothHeaderDelegate(
                          title: 'Recycle Bin',
                          isDark: isDark,
                        ),
                      ),

                      // --- THE CONTENT ---
                      SliverPadding(
                        padding: const EdgeInsets.all(
                          UIConstants.recycleListPadding,
                        ),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final note = deletedNotes[index];
                              return _SwipeableRestoreItem(
                                key: ValueKey(note.id),
                                note: note,
                                isDark: isDark,
                                onShowActionSheet: _showNoteActionSheet,
                                onRestore: _restoreNoteWithUndo,
                              );
                            },
                            childCount: deletedNotes.length,
                            findChildIndexCallback: (key) {
                              final valueKey = key as ValueKey<String>;
                              return idToIndex[valueKey.value];
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(BuildContext context, String text) {
    final screenSize = MediaQuery.of(context).size;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        RepaintBoundary(
          child: Lottie.asset(
            'assets/lotties/Ai_Robot.json',
            renderCache: RenderCache.drawingCommands,
            height: screenSize.height * 0.4,
            width: screenSize.width * 0.4,
            fit: BoxFit.contain,
          ),
        ),
        const SizedBox(height: 24),
        Text(
          text,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).hintColor,
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
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
    required ValueKey<String> key,
  }) : super(key: key);

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
      child: RepaintBoundary(
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

                          double xOffset =
                              (lockPoint / 2) - (draggedPixels / 2);
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
      ),
    );
  }
}

class _SmoothHeaderDelegate extends SliverPersistentHeaderDelegate {
  final String title;
  final bool isDark;

  _SmoothHeaderDelegate({required this.title, required this.isDark});

  // Set both to kToolbarHeight to align perfectly with the BackButton
  @override
  double get minExtent => kToolbarHeight;
  @override
  double get maxExtent => kToolbarHeight;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    // Since min == max, shrinkOffset will generally be 0 or negative (bouncing).
    // We clamp to 1.0 to keep the title centered and still during the bounce.
    final double progress = 1.0;

    // Smoothly transition from 56.0 (Clearance for back button) to 0.0 (Centered)
    // We use actual scroll offset here to drive the horizontal slide.
    final double horizontalSlide = (shrinkOffset / 50.0).clamp(0.0, 1.0);
    final double alignX = ui.lerpDouble(0.0, -1.0, horizontalSlide)!;
    final double leftPadding = ui.lerpDouble(0.0, 56.0, horizontalSlide)!;

    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            const Align(alignment: Alignment.centerLeft, child: BackButton()),
            Align(
              // alignY: 0.0 keeps it perfectly centered with the BackButton
              alignment: Alignment(alignX, 0.0),
              child: Padding(
                padding: EdgeInsets.only(left: leftPadding),
                child: Text(
                  title,
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black,
                    fontWeight: FontWeight.bold,
                    fontSize: 24,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _SmoothHeaderDelegate oldDelegate) => true;
}
