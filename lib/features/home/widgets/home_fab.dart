import 'package:animations/animations.dart';
import 'package:flutter/material.dart';
import 'package:notepad/core/constants/animation_constants.dart';
import 'package:notepad/core/constants/ui_constants.dart';
import 'package:notepad/core/extensions/context_extensions.dart';
import 'package:notepad/core/theme/app_colors.dart';
import 'package:notepad/features/home/controllers/home_controller.dart';
import 'package:notepad/features/home/controllers/selection_controller.dart';
import 'package:notepad/features/home/home_constants.dart';
import 'package:notepad/features/note/note_page.dart';

class HomeFab extends StatelessWidget {
  final HomeController controller;
  final SelectionController selectionController;

  const HomeFab({
    super.key,
    required this.controller,
    required this.selectionController,
  });

  @override
  Widget build(BuildContext context) {
    final bool isSelectionActive = selectionController.isSelectionMode;
    final bool isDraggingActive = controller.isDraggingNote;
    final bool shouldHide = isSelectionActive || isDraggingActive;

    return SafeArea(
      child: AnimatedSlide(
        offset: shouldHide ? const Offset(0, 1.8) : Offset.zero,
        duration: AnimationConstants.medium,
        curve: Curves.fastOutSlowIn,
        child: ListenableBuilder(
          listenable: Listenable.merge([
            controller.fabAlignX,
            controller.isFabExtended,
          ]),
          builder: (context, _) {
            final double alignX = controller.fabAlignX.value;
            final bool isExtended = controller.isFabExtended.value;

            return AnimatedAlign(
              duration: AnimationConstants.slow,
              curve: Curves.easeOutCubic,
              alignment: Alignment(alignX, HomeConstants.fabAlignDefaultY),

              // 🌟 THE SMOOTHNESS FIX: Isolate layout properties here, passing state down cleanly
              child: _OptimizedMorphCanvas(
                isExtended: isExtended,
                shouldHide: shouldHide,
                isSelectionActive: isSelectionActive,
              ),
            );
          },
        ),
      ),
    );
  }
}

class _OptimizedMorphCanvas extends StatelessWidget {
  final bool isExtended;
  final bool shouldHide;
  final bool isSelectionActive;

  const _OptimizedMorphCanvas({
    required this.isExtended,
    required this.shouldHide,
    required this.isSelectionActive,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    final Color fabColor = isDark
        ? AppColors.homeFabDark
        : AppColors.homeFabLight;
    final Color contentColor = isDark
        ? Colors.black.withValues(alpha: 0.8)
        : Colors.white;

    const double expandedWidth = HomeConstants.fabExpandedWidth;
    const double collapsedWidth = HomeConstants.fabCollapsedWidth;
    const double fabHeight = HomeConstants.fabHeight;

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(
        begin: isExtended ? expandedWidth : collapsedWidth,
        end: isExtended ? expandedWidth : collapsedWidth,
      ),
      duration: AnimationConstants.medium,
      curve: Curves.easeOutBack,
      builder: (context, animatedWidth, child) {
        return SizedBox(
          height: fabHeight,
          width: animatedWidth,
          child: OpenContainer(
            // 🛠️ FIX 1: Use shared axis scaling fade, built for expanding components
            transitionType: ContainerTransitionType.fade,
            // 🛠️ FIX 2: Give the GPU 350ms to draw the full canvas smoothly
            transitionDuration: const Duration(milliseconds: 350),
            openColor: Theme.of(context).scaffoldBackgroundColor,
            closedColor: fabColor,
            // 🛠️ FIX 3: Pass your exact fabColor to the mid-transition layer.
            // This instantly kills that ugly translucent grey block artifact!
            middleColor: fabColor,
            closedElevation: isSelectionActive ? 0 : UIConstants.elevationHigh,
            closedShape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(
                HomeConstants.fabClosedRadius,
              ),
            ),
            openShape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.zero,
            ),
            closedBuilder: (context, openContainer) => RepaintBoundary(
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: shouldHide ? null : openContainer,
                  // 🛠️ FIX 4: Replace default muddy system ripples with a high-fidelity subtle splash
                  splashColor: contentColor.withValues(alpha: 0.12),
                  highlightColor: Colors.transparent,
                  child: TweenAnimationBuilder<double>(
                    tween: Tween<double>(end: isExtended ? 1.0 : 0.0),
                    duration: AnimationConstants.fast,
                    curve: Curves.easeInOutCubic,
                    builder: (context, animationProgress, _) {
                      return CustomPaint(
                        size: Size(animatedWidth, fabHeight),
                        painter: FluidFabPainter(
                          contentColor: contentColor,
                          progress: animationProgress,
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
            openBuilder: (context, _) => const NotePage(),
          ),
        );
      },
    );
  }
}

// Keep your existing FluidFabPainter completely as it is!
class FluidFabPainter extends CustomPainter {
  final Color contentColor;
  final double progress;

  FluidFabPainter({required this.contentColor, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.clipRect(Rect.fromLTWH(0, 0, size.width, size.height));

    final iconPainter = TextPainter(
      textDirection: TextDirection.ltr,
      text: TextSpan(
        text: String.fromCharCode(Icons.edit.codePoint),
        style: TextStyle(
          fontSize: UIConstants.iconMD,
          fontFamily: Icons.edit.fontFamily,
          package: Icons.edit.fontPackage,
          color: contentColor,
        ),
      ),
    )..layout();

    final double iconX = HomeConstants.fabCollapsedIconSpacing;
    final double iconY = (size.height - UIConstants.iconMD) / 2;
    iconPainter.paint(canvas, Offset(iconX, iconY));

    if (progress > 0.05) {
      final double textFade = Curves.easeIn.transform(progress);
      final double slideOffset = (1.0 - progress) * -12.0;

      final textPainter = TextPainter(
        textDirection: TextDirection.ltr,
        maxLines: 1,
        text: TextSpan(
          text: 'New Note',
          style: TextStyle(
            color: contentColor.withValues(alpha: textFade),
            fontWeight: FontWeight.bold,
            fontSize: HomeConstants.fabTextFontSize,
          ),
        ),
      )..layout();

      final double textStartX =
          HomeConstants.fabCollapsedIconSpacing +
          UIConstants.iconMD +
          HomeConstants.fabTextSpacing;
      final double textX = textStartX + slideOffset;
      final double textY = (size.height - textPainter.height) / 2;

      textPainter.paint(canvas, Offset(textX, textY));
    }
  }

  @override
  bool shouldRepaint(covariant FluidFabPainter oldDelegate) {
    return oldDelegate.contentColor != contentColor ||
        oldDelegate.progress != progress;
  }
}
