import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:notepad/core/constants/animation_constants.dart';
import 'package:notepad/core/constants/ui_constants.dart';
import 'package:notepad/core/database/app_data.dart';
import 'package:notepad/core/extensions/context_extensions.dart';
import 'package:notepad/core/services/ui_management/app_router.dart';
import 'package:notepad/core/theme/app_colors.dart';
import 'package:notepad/features/note/note_page.dart';
import 'package:notepad/features/trash/recycle_constants.dart';

// Swipe actions restore or permanently delete notes from the recycle bin.
class SwipeableRestoreItem extends StatefulWidget {
  const SwipeableRestoreItem({
    required ValueKey<String> key,
    required this.cardWidth,
    required this.note,
    required this.onRestore,
    required this.onShowActionSheet,
  }) : super(key: key);

  final double cardWidth;
  final NotesSection note;
  final void Function(NotesSection) onRestore;
  final void Function(BuildContext, NotesSection) onShowActionSheet;

  @override
  State<SwipeableRestoreItem> createState() => _SwipeableRestoreItemState();
}

class _SwipeableRestoreItemState extends State<SwipeableRestoreItem> {
  bool get isDark => context.isDark;
  double get cardWidth => widget.cardWidth;

  final ValueNotifier<double> _dragProgress = ValueNotifier<double>(0.0);
  final ValueNotifier<bool> _isConfirmed = ValueNotifier<bool>(false);

  @override
  void dispose() {
    _dragProgress.dispose();
    _isConfirmed.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final previewLines = widget.note.getPreview(
      3,
      normalizedContent: widget.note.content,
    );
    final subtitleText = previewLines.map((line) => line.text).join('\n');

    return Padding(
      padding: const EdgeInsets.all(RecycleConstants.cardMargin),
      child: Stack(
        children: [
          Positioned(
            top: 0,
            bottom: 0,
            left: 0,
            right: 0,
            child: Card(
              margin: const EdgeInsets.symmetric(
                vertical: 0,
                horizontal: UIConstants.paddingXXS,
              ),
              elevation: 0,
              color: isDark
                  ? AppColors.recycleSwipeDark
                  : AppColors.recycleSwipeLight,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(
                  RecycleConstants.cardRadius * 2.5,
                ),
              ),
              child: Container(
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: UIConstants.paddingXL),
                child: ListenableBuilder(
                  listenable: Listenable.merge([_dragProgress, _isConfirmed]),
                  builder: (context, child) {
                    final progress = _dragProgress.value;
                    final isConfirmed = _isConfirmed.value;

                    final draggedPixels = progress * cardWidth;
                    const iconWidth = RecycleConstants.iconSize;
                    const targetPadding = 16.0;

                    const appearanceThreshold =
                        RecycleConstants.swipeAppearanceThreshold;

                    final animationProgress =
                        ((draggedPixels - appearanceThreshold) /
                                (cardWidth *
                                    RecycleConstants.swipeRevealFraction))
                            .clamp(0.0, 1.0);

                    const lockPoint = (targetPadding * 2) + iconWidth;

                    double xOffset = (lockPoint / 2) - (draggedPixels / 2);
                    xOffset = xOffset.clamp(0.0, double.infinity);

                    final scale = ui.lerpDouble(
                      RecycleConstants.swipeIconStartScale,
                      1.0,
                      animationProgress,
                    )!;
                    final opacity = animationProgress;

                    final rotationProgress = (draggedPixels / lockPoint).clamp(
                      0.0,
                      2.0,
                    );
                    final angle = rotationProgress * pi;

                    final matrix = Matrix4.identity()
                      ..translateByDouble(-xOffset, 0, 0, 1)
                      ..rotateZ(angle)
                      ..scaleByDouble(scale, scale, scale, 1);

                    final baseColor = isDark
                        ? AppColors.recycleRestoreDark
                        : AppColors.recycleRestoreLight;

                    return AnimatedOpacity(
                      duration: AnimationConstants.fast,
                      curve: Curves.easeOut,
                      opacity: isConfirmed ? 0.0 : opacity,
                      child: AnimatedScale(
                        duration: AnimationConstants.fast,
                        curve: Curves.easeInBack,
                        scale: isConfirmed
                            ? RecycleConstants.swipeConfirmedScale
                            : 1.0,
                        child: Transform(
                          alignment: Alignment.center,
                          transform: matrix,
                          child: Icon(
                            Icons.restore,
                            color: baseColor,
                            size: RecycleConstants.iconSize,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),

          Dismissible(
            key: ValueKey('restore_${widget.note.id}'),
            direction: DismissDirection.endToStart,
            background: const ColoredBox(color: Colors.transparent),
            confirmDismiss: (direction) async {
              _isConfirmed.value = true;
              return true;
            },
            onUpdate: (details) {
              if (!mounted) return;
              if ((details.progress - _dragProgress.value).abs() >
                  RecycleConstants.swipeMinimumProgressDelta) {
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
                // 🌟 CRITICAL: Clips the bottom indicator bar to the card's rounded corners
                clipBehavior: Clip.antiAlias,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(
                    RecycleConstants.cardRadius,
                  ),
                ),
                child: InkWell(
                  onLongPress: () {
                    HapticFeedback.mediumImpact();
                  },
                  onTap: () {
                    Navigator.of(context).push(
                      AppRouter.slide(
                        NotePage(noteId: widget.note.id, readOnly: true),
                      ),
                    );
                  },
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // 1. Core Content Area
                      Padding(
                        padding: const EdgeInsets.all(
                          RecycleConstants.cardPadding,
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    widget.note.displayTitle,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 8.0),
                                  Text(
                                    subtitleText,
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      height: 1.3,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              onPressed: () => widget.onShowActionSheet(
                                context,
                                widget.note,
                              ),
                              icon: Icon(
                                Icons.more_vert,
                                color: isDark ? Colors.white : Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),

                      // 2. The Days Remaining Bottom Strip Indicator
                      Container(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.12)
                            : Colors.grey[600],
                        padding: const EdgeInsets.symmetric(vertical: 6.0),
                        alignment: Alignment.center,
                        child: Text(
                          '${widget.note.daysLeft} days left',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12.0,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
