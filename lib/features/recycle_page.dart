import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lottie/lottie.dart';
import 'package:notepad/core/constants/ui_constants.dart';
import 'package:notepad/core/data/app_data.dart';
import 'package:notepad/core/data/notes_repository.dart';
import 'package:notepad/core/services/note_timestamp_formatter.dart';
import 'package:notepad/core/services/scaffold_messenger_notifier.dart';
import 'package:notepad/core/theme/app_colors.dart';
import 'package:notepad/features/note/note_page.dart';
import 'package:notepad/core/services/context_extensions.dart';

class RecyclePage extends StatefulWidget {
  const RecyclePage({super.key});

  @override
  State<RecyclePage> createState() => _RecyclePageState();
}

class _RecyclePageState extends State<RecyclePage> {
  bool get isDark => context.isDark;

  Future<void> _restoreNoteWithUndo(NotesSection note) async {
    final title = note.displayTitle;
    final isRestored = await noteRepository.toggleDeletedStatus(note.id, false);

    if (!(mounted && isRestored)) {
      debugPrint("The note: $note.id couldn't be restored.");
      return;
    }

    showRestorationSnackBar(
      message: '$title is now restored.',
      onUndo: () async =>
          await noteRepository.toggleDeletedStatus(note.id, true),
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

  Widget _buildEmptyState(BuildContext context, String text) {
    final screenSize = MediaQuery.of(context).size;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        RepaintBoundary(
          child: Lottie.asset(
            'assets/lotties/Ai_Robot.json',
            renderCache: RenderCache.drawingCommands,
            height: screenSize.height * 0.5,
            width: screenSize.width * 0.5,
            fit: BoxFit.contain,
          ),
        ),
        //const SizedBox(height: 5),
        Transform.translate(
          offset: const Offset(0, -50), // Adjust this value to your liking
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).hintColor,
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final notesEmptyText = "Your trash is squeaky clean.";
    final cardWidth =
        MediaQuery.sizeOf(context).width - (UIConstants.recycleListPadding * 2);

    return Scaffold(
      backgroundColor: isDark
          ? AppColors.darkScaffold
          : AppColors.lightScaffold,
      body: SafeArea(
        child: ListenableBuilder(
          listenable: noteRepository,
          builder: (context, child) {
            // This logic now only runs when the repository notifies
            final deletedNotes = noteRepository.deletedNotes;

            // Inner conditional: Only the content area swaps
            if (deletedNotes.isEmpty) {
              return Column(
                children: [
                  _StaticHeader(isDark: isDark), // Helper for the top bar
                  Expanded(child: _buildEmptyState(context, notesEmptyText)),
                ],
              );
            }

            return CustomScrollView(
              physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              slivers: [
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _SmoothHeaderDelegate(
                    title: 'Recycle Bin',
                    isDark: isDark,
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.all(UIConstants.recycleListPadding),
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
                          cardWidth: cardWidth,
                        );
                      },
                      childCount: deletedNotes.length,
                      findChildIndexCallback: (key) {
                        final valueKey = key as ValueKey<String>;
                        return noteRepository.getDeletedIndex(valueKey.value);
                      },
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
    required this.cardWidth,
  }) : super(key: key);

  final NotesSection note;
  final bool isDark;
  final double cardWidth;
  final void Function(NotesSection) onRestore;
  final void Function(BuildContext, NotesSection) onShowActionSheet;

  @override
  State<_SwipeableRestoreItem> createState() => _SwipeableRestoreItemState();
}

class _SwipeableRestoreItemState extends State<_SwipeableRestoreItem> {
  @override
  void dispose() {
    _dragProgress.dispose();
    _isConfirmed.dispose();
    super.dispose();
  }

  double get cardWidth => widget.cardWidth;

  // ISOLATED STATE: Tracks the thumb!
  final ValueNotifier<double> _dragProgress = ValueNotifier<double>(0.0);

  // Tracks when the swipe is confirmed to trigger the exit animation
  final ValueNotifier<bool> _isConfirmed = ValueNotifier<bool>(false);

  @override
  Widget build(BuildContext context) {
    final previewLines = widget.note.getPreview(1);
    final subtitleText = previewLines.isNotEmpty
        ? previewLines.first
        : 'No additional text';

    return Padding(
      padding: const EdgeInsets.all(UIConstants.recycleCardMargin),
      child: Stack(
        children: [
          // --- THE PERMANENT GREEN BACKGROUND ---
          Positioned(
            top: 0.5,
            bottom: 0.5,
            right: 0.5,
            left: 16,
            child: RepaintBoundary(
              child: Card(
                margin: EdgeInsets.zero,
                elevation: 0,
                color: widget.isDark
                    ? const Color(0xFF003D33)
                    : const Color(0xFFC8E6C9),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.horizontal(
                    right: Radius.circular(UIConstants.recycleCardRadius - 1.0),
                    left: Radius.zero,
                  ),
                ),
                child: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: UIConstants.paddingLG),
                  child: ListenableBuilder(
                    listenable: Listenable.merge([_dragProgress, _isConfirmed]),
                    builder: (context, child) {
                      // Extract the current values
                      final progress = _dragProgress.value;
                      final isConfirmed = _isConfirmed.value;

                      final draggedPixels = progress * cardWidth;
                      const iconWidth = UIConstants.recycleIconSize;
                      const targetPadding = UIConstants.paddingLG;

                      // 1. Define a threshold (The "Dead Zone")
                      // The icon won't start appearing until we've swiped 30 pixels.
                      const appearanceThreshold = 30.0;

                      // 2. Adjust the animation progress to account for the threshold
                      final animationProgress =
                          ((draggedPixels - appearanceThreshold) /
                                  (cardWidth * 0.3))
                              .clamp(0.0, 1.0);

                      const lockPoint = (targetPadding * 2) + iconWidth;

                      double xOffset = (lockPoint / 2) - (draggedPixels / 2);
                      xOffset = xOffset.clamp(0.0, double.infinity);

                      // Use the new animationProgress for scale and opacity
                      final scale = ui.lerpDouble(0.5, 1.0, animationProgress)!;
                      final opacity =
                          animationProgress; // 0.0 until we hit 30px

                      final rotationProgress = (draggedPixels / lockPoint)
                          .clamp(0.0, 2.0);
                      final angle = rotationProgress * pi;

                      final matrix = Matrix4.identity()
                        ..translateByDouble(xOffset, 0, 0, 1)
                        ..rotateZ(angle)
                        ..scaleByDouble(scale, scale, scale, 1);

                      final baseColor = widget.isDark
                          ? const Color(0xFF69F0AE)
                          : const Color(0xFF2E7D32);

                      return AnimatedOpacity(
                        duration: const Duration(milliseconds: 150),
                        curve: Curves.easeOut,
                        // Reacts to the merged state instantly
                        opacity: isConfirmed ? 0.0 : opacity,
                        child: AnimatedScale(
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeInBack,
                          scale: isConfirmed ? 0.0 : 1.0,
                          child: Transform(
                            alignment: Alignment.center,
                            transform: matrix,
                            child: Icon(
                              Icons.restore,
                              color: baseColor,
                              size: UIConstants.recycleIconSize,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),

          // --- THE SWIPE MASK ---
          Dismissible(
            key: ValueKey('restore_${widget.note.id}'),
            direction: DismissDirection.endToStart,
            background: const ColoredBox(color: Colors.transparent),
            confirmDismiss: (direction) async {
              _isConfirmed.value = true;
              return true; // Tell Flutter to proceed with the row collapse
            },
            onUpdate: (details) {
              if (!mounted) return;
              if ((details.progress - _dragProgress.value).abs() > 0.01) {
                _dragProgress.value = details.progress;
              }
            },
            onDismissed: (_) {
              widget.onRestore(widget.note);
            },

            child: RepaintBoundary(
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
                  title: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.note.title.isEmpty
                            ? 'Untitled note'
                            : widget.note.title,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),

                      // const SizedBox(height: UIConstants.paddingSM),
                    ],
                  ),
                  subtitle: Text(
                    subtitleText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Colors.grey[500]),
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
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => NotePage(
                          noteId: widget.note.id,
                          readOnly: true, // Opens in preview mode
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ],
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
  bool shouldRebuild(covariant _SmoothHeaderDelegate oldDelegate) {
    return oldDelegate.title != title || oldDelegate.isDark != isDark;
  }
}

class _StaticHeader extends StatelessWidget {
  final bool isDark;
  const _StaticHeader({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: kToolbarHeight,
      child: Stack(
        children: [
          const Align(alignment: Alignment.centerLeft, child: BackButton()),
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
    );
  }
}
