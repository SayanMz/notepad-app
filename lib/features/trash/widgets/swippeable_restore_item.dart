import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:notepad/core/constants/animation_constants.dart';
import 'package:notepad/core/constants/ui_constants.dart';
import 'package:notepad/core/data/app_data.dart';
import 'package:notepad/core/theme/app_colors.dart';
import 'package:notepad/features/note/note_page.dart';
import 'package:notepad/features/trash/recycle_constants.dart';

class SwipeableRestoreItem extends StatefulWidget {
  const SwipeableRestoreItem({
    required this.note,
    required this.isDark,
    required this.onRestore,
    required this.onShowActionSheet,
    required ValueKey<String> key,
    required this.cardWidth,
  }) : super(key: key);

  final NotesSection note; //
  final bool isDark; //
  final double cardWidth; //
  final void Function(NotesSection) onRestore; //
  final void Function(BuildContext, NotesSection) onShowActionSheet; //

  @override
  State<SwipeableRestoreItem> createState() => _SwipeableRestoreItemState();
}

class _SwipeableRestoreItemState extends State<SwipeableRestoreItem> {
  // ISOLATED STATE: Tracks the thumb!
  final ValueNotifier<double> _dragProgress = ValueNotifier<double>(0.0); //

  // Tracks when the swipe is confirmed to trigger the exit animation
  final ValueNotifier<bool> _isConfirmed = ValueNotifier<bool>(false); //

  @override
  void dispose() {
    _dragProgress.dispose(); //
    _isConfirmed.dispose(); //
    super.dispose();
  }

  double get cardWidth => widget.cardWidth; //

  @override
  Widget build(BuildContext context) {
    final previewLines = widget.note.getPreview(
      1,
      normalizedContent: widget.note.content,
    ); //
    final subtitleText = previewLines.isNotEmpty
        ? previewLines
              .first //
        : 'No additional text'; //

    return Padding(
      padding: const EdgeInsets.all(RecycleConstants.cardMargin), //
      child: Stack(
        children: [
          // --- THE PERMANENT GREEN BACKGROUND ---
          Positioned(
            top: RecycleConstants.swipeBackgroundInset, //
            bottom: RecycleConstants.swipeBackgroundInset, //
            right: RecycleConstants.swipeBackgroundInset, //
            left: RecycleConstants.swipeBackgroundLeft, //
            child: Card(
              margin: EdgeInsets.zero, //
              elevation: 0, //
              color: widget.isDark
                  ? AppColors
                        .recycleSwipeDark //
                  : AppColors.recycleSwipeLight, //
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.horizontal(
                  right: Radius.circular(
                    RecycleConstants.cardRadius - //
                        UIConstants.toolbarBorderWidth, //
                  ),
                  left: Radius.zero, //
                ),
              ),
              child: Container(
                alignment: Alignment.centerRight, //
                padding: const EdgeInsets.only(right: UIConstants.paddingLG), //
                child: ListenableBuilder(
                  listenable: Listenable.merge([
                    _dragProgress,
                    _isConfirmed,
                  ]), //
                  builder: (context, child) {
                    final progress = _dragProgress.value; //
                    final isConfirmed = _isConfirmed.value; //

                    final draggedPixels = progress * cardWidth; //
                    const iconWidth = RecycleConstants.iconSize; //
                    const targetPadding = 16.0; //

                    const appearanceThreshold =
                        RecycleConstants.swipeAppearanceThreshold; //

                    final animationProgress =
                        ((draggedPixels - appearanceThreshold) /
                                (cardWidth *
                                    RecycleConstants.swipeRevealFraction))
                            .clamp(0.0, 1.0); //

                    const lockPoint = (targetPadding * 2) + iconWidth; //

                    double xOffset = (lockPoint / 2) - (draggedPixels / 2); //
                    xOffset = xOffset.clamp(0.0, double.infinity); //

                    final scale = ui.lerpDouble(
                      RecycleConstants.swipeIconStartScale, //
                      1.0, //
                      animationProgress,
                    )!;
                    final opacity = animationProgress; //

                    final rotationProgress = (draggedPixels / lockPoint).clamp(
                      0.0,
                      2.0,
                    ); //
                    final angle = rotationProgress * pi; //

                    final matrix = Matrix4.identity()
                      ..translateByDouble(xOffset, 0, 0, 1) //
                      ..rotateZ(angle) //
                      ..scaleByDouble(scale, scale, scale, 1); //

                    final baseColor = widget.isDark
                        ? AppColors
                              .recycleRestoreDark //
                        : AppColors.recycleRestoreLight; //

                    return AnimatedOpacity(
                      duration: AnimationConstants.fast, //
                      curve: Curves.easeOut, //
                      opacity: isConfirmed ? 0.0 : opacity, //
                      child: AnimatedScale(
                        duration: AnimationConstants.fast, //
                        curve: Curves.easeInBack, //
                        scale: isConfirmed
                            ? RecycleConstants
                                  .swipeConfirmedScale //
                            : 1.0,
                        child: Transform(
                          alignment: Alignment.center, //
                          transform: matrix, //
                          child: Icon(
                            Icons.restore, //
                            color: baseColor, //
                            size: RecycleConstants.iconSize, //
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
            key: ValueKey('restore_${widget.note.id}'), //
            direction: DismissDirection.endToStart, //
            background: const ColoredBox(color: Colors.transparent), //
            confirmDismiss: (direction) async {
              _isConfirmed.value = true; //
              return true; //
            },
            onUpdate: (details) {
              if (!mounted) return;
              if ((details.progress - _dragProgress.value).abs() >
                  RecycleConstants.swipeMinimumProgressDelta) {
                //
                _dragProgress.value = details.progress; //
              }
            },
            onDismissed: (_) {
              widget.onRestore(widget.note); //
            },
            child: RepaintBoundary(
              child: Card(
                margin: EdgeInsets.zero, //
                elevation: UIConstants.elevationLow, //
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(
                    RecycleConstants.cardRadius, //
                  ),
                ),
                child: ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(
                      RecycleConstants.cardRadius, //
                    ),
                  ),
                  contentPadding: const EdgeInsets.all(
                    RecycleConstants.cardPadding, //
                  ),
                  title: Column(
                    crossAxisAlignment: CrossAxisAlignment.start, //
                    children: [
                      Text(
                        widget.note.displayTitle,
                        style: const TextStyle(fontWeight: FontWeight.bold), //
                      ),
                    ],
                  ),
                  subtitle: Text(
                    subtitleText, //
                    maxLines: 1, //
                    overflow: TextOverflow.ellipsis, //
                    style: TextStyle(color: Colors.grey[500]), //
                  ),
                  trailing: IconButton(
                    onPressed: () =>
                        widget.onShowActionSheet(context, widget.note), //
                    icon: Icon(
                      Icons.more_vert, //
                      color: widget.isDark ? Colors.white : Colors.blue, //
                    ),
                  ),
                  onLongPress: HapticFeedback.mediumImpact, //
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => NotePage(
                          noteId: widget.note.id, //
                          readOnly: true, //
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
