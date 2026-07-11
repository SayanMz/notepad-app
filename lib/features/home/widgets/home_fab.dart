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
    final double fabHeight = HomeConstants.fabHeight;

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: isExtended ? expandedWidth : collapsedWidth),
      duration: AnimationConstants.medium,
      curve: Curves.easeOutCubic,
      builder: (context, animatedWidth, child) {
        return SizedBox(
          height: fabHeight,
          width: animatedWidth,
          child: RepaintBoundary(
            child: Material(
              color: fabColor,
              elevation: isSelectionActive ? 0 : UIConstants.elevationHigh,
              borderRadius: BorderRadius.circular(
                HomeConstants.fabClosedRadius,
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(
                  HomeConstants.fabClosedRadius,
                ),
                onTap: shouldHide
                    ? null
                    : () {
                        // 🌟 THE NEW ROUTE RUNNER: Pushes the smooth shared axis page scale transition
                        Navigator.of(context).push(_createSharedAxisRoute());
                      },
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
        );
      },
    );
  }

  // 🛠️ THE SMOOTHNESS FIX: High-performance Shared Axis Page Scale transition
  Route _createSharedAxisRoute() {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => const NotePage(),
      transitionDuration: const Duration(milliseconds: 300),
      reverseTransitionDuration: const Duration(milliseconds: 250),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        // Shared Axis Scale: Page scales from 0.92 to 1.0 smoothly
        final scaleTween = Tween<double>(begin: 0.92, end: 1.0).animate(
          CurvedAnimation(parent: animation, curve: Curves.fastOutSlowIn),
        );

        // Shared Axis Fade: Page fades in gracefully alongside the scale matrix
        final fadeTween = Tween<double>(begin: 0.0, end: 1.0).animate(
          CurvedAnimation(
            parent: animation,
            curve: const Interval(0.0, 0.8, curve: Curves.easeOut),
          ),
        );

        return FadeTransition(
          opacity: fadeTween,
          child: ScaleTransition(scale: scaleTween, child: child),
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
