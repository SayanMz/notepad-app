import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:notepad/core/constants/ui_constants.dart';
import 'package:notepad/core/data/app_data.dart';
import 'package:notepad/core/services/context_extensions.dart';
import 'package:notepad/core/theme/app_colors.dart';
import 'package:notepad/features/home/controllers/animation_controller.dart';
import 'package:notepad/features/home/controllers/home_controller.dart';
import 'package:notepad/features/home/services/app_router.dart';
import 'package:notepad/features/home/widgets/note_list_items/animated_trash_icon.dart';
import 'package:notepad/features/home/widgets/note_list_items/note_card.dart';
import 'package:notepad/features/note/note_page.dart';

class SwipeableNoteItem extends StatefulWidget {
  const SwipeableNoteItem({
    super.key,
    required this.index,
    required this.note,
    required this.controller,
    required this.animationController,
    required this.maxPreviewLines,
  });

  final int index;
  final NotesSection note;
  final HomeController controller;
  final AnimationControllerState animationController;
  final int maxPreviewLines;

  @override
  State<SwipeableNoteItem> createState() => _SwipeableNoteItemState();
}

class _SwipeableNoteItemState extends State<SwipeableNoteItem> {
  final ValueNotifier<double> _dragProgress = ValueNotifier<double>(0.0);
  final ValueNotifier<bool> _isConfirmed = ValueNotifier<bool>(false);

  bool _hasSnapped = false;

  @override
  void dispose() {
    _dragProgress.dispose();
    _isConfirmed.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: UIConstants.cardVerticalMargin,
        horizontal: UIConstants.paddingSM,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final cardWidth = constraints.maxWidth;
          return Stack(
            children: [
              // --- THE BACKGROUND PANEL LAYER (PATH B: FLOATING CAPSULE) ---
              Positioned(
                // 🌟 MATCH OUTSIDE EDGE BOUNDARIES OF THE NOTECARD FOR LAYERING
                top: 0,
                bottom: 0,
                left: 0,
                right: 0,
                    child: ListenableBuilder(
                      listenable: Listenable.merge([_dragProgress, _isConfirmed]),
                      builder: (context, _) {
                    final progress = _dragProgress.value;
                    final isConfirmed = _isConfirmed.value;

                    final bool shouldShowBackground =
                        progress > 0.0 &&
                        !widget.controller.selectionController.isSelectionMode;

                    return AnimatedOpacity(
                      opacity: shouldShowBackground ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 100),
                      curve: Curves.easeOut,
                      child: RepaintBoundary(
                        child: Card(
                          // 🌟 INSET MARGINS INWARD: Shaves top/bottom/sides for capsule separation
                          margin: const EdgeInsets.symmetric(
                            vertical: UIConstants.paddingXXS + 4,
                            horizontal: UIConstants.paddingXXS,
                          ),
                          elevation: 0,
                          color: context.isDark
                              ? AppColors.deleteDarkBg
                              : AppColors.deleteLightBg,
                          // 🌟 EXAGGERATED BORDER RADIUS: Standardized capsule curve shape
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              UIConstants.radiusMD * 2.5,
                            ),
                          ),
                          child: Container(
                            alignment: Alignment.centerLeft,
                            padding: const EdgeInsets.only(
                              left: UIConstants
                                  .paddingXL, // Tighter interior padding for action target
                            ),
                            child: Builder(
                              builder: (context) {
                                final draggedPixels = progress * cardWidth;
                                const iconWidth = UIConstants.iconLG;
                                const targetPadding = UIConstants.paddingLG;
                                const lockPoint =
                                    (targetPadding * 2) + iconWidth;

                                double xOffset =
                                    (draggedPixels / 2) - (iconWidth / 2);
                                xOffset = xOffset.clamp(
                                  double.negativeInfinity,
                                  targetPadding,
                                );

                                final double activeRange =
                                    cardWidth - lockPoint;
                                double normalized =
                                    ((draggedPixels - lockPoint) / activeRange)
                                        .clamp(0.0, 1.0);
                                final double rawLidProgress =
                                    1.0 - (2.0 * normalized - 1.0).abs();
                                final double finalLidProgress = Curves.easeIn
                                    .transform(rawLidProgress.clamp(0.0, 1.0));

                                final scale = _hasSnapped
                                    ? 1.1
                                    : (draggedPixels / lockPoint).clamp(
                                        0.5,
                                        1.0,
                                      );
                                final iconOpacity = (draggedPixels / lockPoint)
                                    .clamp(0.0, 1.0);

                                return AnimatedOpacity(
                                  duration: const Duration(milliseconds: 150),
                                  curve: Curves.easeOut,
                                  opacity: isConfirmed ? 0.0 : iconOpacity,
                                  child: AnimatedScale(
                                    duration: const Duration(milliseconds: 200),
                                    curve: Curves.easeInBack,
                                    scale: isConfirmed ? 0.0 : 1.0,
                                    child: Transform.translate(
                                      offset: Offset(xOffset, 0),
                                      child: Transform.scale(
                                        scale: scale,
                                        child: AnimatedTrashIcon(
                                          lidProgress: finalLidProgress,
                                          color: context.isDark
                                              ? AppColors.deleteDarkIcon
                                              : AppColors.deleteLightIcon,
                                          size: UIConstants.iconLG,
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
                    );
                  },
                ),
              ),

              // --- THE SWIPE MASK SURFACE LAYER ---
              Dismissible(
                key: ValueKey('dismiss_${widget.note.id}'),
                direction: widget.controller.selectionController.isSelectionMode
                    ? DismissDirection.none
                    : DismissDirection.startToEnd,
                background: const ColoredBox(color: Colors.transparent),
                confirmDismiss: (direction) async {
                  _isConfirmed.value = true;
                  return true;
                },
                onUpdate: (details) {
                  if (!mounted) return;

                  final lockProgress =
                      ((UIConstants.paddingLG * 2) + UIConstants.iconLG) /
                      cardWidth;

                  if (details.progress >= lockProgress && !_hasSnapped) {
                    HapticFeedback.lightImpact();
                    _hasSnapped = true;
                  } else if (details.progress < lockProgress && _hasSnapped) {
                    _hasSnapped = false;
                  }

                  if (details.progress == 0.0 ||
                      (details.progress - _dragProgress.value).abs() > 0.01) {
                    _dragProgress.value = details.progress;
                  }
                },
                onDismissed: (_) {
                  HapticFeedback.mediumImpact();
                  widget.controller.executeSingleDelete(widget.note.id);
                },
                child: RepaintBoundary(
                  child: NoteCard(
                    index: widget.index,
                    note: widget.note,
                    isSelectionMode:
                        widget.controller.selectionController.isSelectionMode,
                    isVaporizing: widget.animationController.isVaporizing(
                      widget.note.id,
                    ),
                    onPin: () => widget.controller.togglePin(widget.note.id),
                    colorNotifier: widget.controller.colorChangeNotifier,
                    maxPreviewLines: widget.maxPreviewLines,
                    selectionMode:
                        widget.controller.selectionController.isSelectionMode,
                    isSelected: widget.controller.selectionController.isNoteSelected(
                      widget.note.id,
                    ),
                    onTap: () async {
                      if (widget.controller.selectionController.isSelectionMode) {
                        widget.controller.selectionController.toggleSelected(
                          widget.note.id,
                        );
                        return;
                      }
                      widget.controller.openNote(
                        noteId: widget.note.id,
                        onNavigate: (id) async => Navigator.push(
                          context,
                          AppRouter.slide(NotePage(noteId: id)),
                        ),
                      );
                    },
                    onLongPress: () {
                      HapticFeedback.selectionClick();
                      widget.controller.selectionController.toggleSelected(
                        widget.note.id,
                      );
                    },
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
