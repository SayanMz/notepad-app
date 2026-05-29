import 'package:animations/animations.dart';
import 'package:flutter/material.dart';
import 'package:notepad/core/constants/animation_constants.dart';
import 'package:notepad/core/constants/ui_constants.dart';
import 'package:notepad/core/services/context_extensions.dart';
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

  // 📍 Location: home_fab.dart -> Inside your build method

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark; //
    final Color fabColor = isDark
        ? AppColors.homeFabDark
        : AppColors.homeFabLight; //
    final Color contentColor = isDark
        ? Colors.black.withValues(alpha: 0.8)
        : Colors.white; //

    const double expandedWidth = HomeConstants.fabExpandedWidth; //
    const double collapsedWidth = HomeConstants.fabCollapsedWidth; //
    const double fabHeight = HomeConstants.fabHeight; //
    const Curve fluidCurve = Curves.easeOutBack; //

    final bool isSelectionActive = selectionController.isSelectionMode; //
    final bool isDraggingActive = controller.isDraggingNote; //
    final bool shouldHide = isSelectionActive || isDraggingActive; //

    return SafeArea(
      child: AnimatedSlide(
        offset: shouldHide ? const Offset(0, 1.8) : Offset.zero, //
        duration: AnimationConstants.medium, //
        curve: Curves.fastOutSlowIn, //
        // 🌟 THE MERGE FIX: Listen to both properties at the same time cleanly
        child: ListenableBuilder(
          listenable: Listenable.merge([
            controller.fabAlignX,
            controller.isFabExtended,
          ]),
          builder: (context, _) {
            final double alignX = controller.fabAlignX.value; //
            final bool isExtended = controller.isFabExtended.value;

            return AnimatedAlign(
              duration: AnimationConstants.slow, //
              curve: Curves.easeOutCubic, //
              alignment: Alignment(alignX, HomeConstants.fabAlignDefaultY), //
              // Localized animation tree stays completely isolated from alignment rebuilds!
              child: TweenAnimationBuilder<double>(
                tween: Tween<double>(
                  begin: isExtended ? expandedWidth : collapsedWidth,
                  end: isExtended ? expandedWidth : collapsedWidth,
                ),
                duration: AnimationConstants.medium, //
                curve: fluidCurve, //
                builder: (context, animatedWidth, child) {
                  return SizedBox(
                    height: fabHeight, //
                    width: animatedWidth,
                    child: OpenContainer(
                      transitionType: ContainerTransitionType.fadeThrough, //
                      transitionDuration: const Duration(milliseconds: 180), //
                      openColor: Theme.of(context).scaffoldBackgroundColor, //
                      closedColor: fabColor, //
                      closedElevation: isSelectionActive
                          ? 0
                          : UIConstants.elevationHigh, //
                      closedShape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          HomeConstants.fabClosedRadius,
                        ), //
                      ),
                      openShape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.zero,
                      ), //
                      middleColor: Colors.transparent, //

                      closedBuilder: (context, openContainer) =>
                          RepaintBoundary(
                            //
                            child: Material(
                              color: Colors.transparent, //
                              child: InkWell(
                                onTap: shouldHide ? null : openContainer, //
                                child: TweenAnimationBuilder<double>(
                                  tween: Tween<double>(
                                    end: isExtended ? 1.0 : 0.0,
                                  ), //
                                  duration: AnimationConstants.fast, //
                                  curve: Curves.easeInOutCubic, //
                                  builder: (context, animationProgress, _) {
                                    return CustomPaint(
                                      size: Size(animatedWidth, fabHeight), //
                                      painter: FluidFabPainter(
                                        contentColor: contentColor, //
                                        progress: animationProgress, //
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                          ),
                      openBuilder: (context, _) => const NotePage(), //
                    ),
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }
}

/// ⚡ Fluid Canvas Painter applying dynamic structural stagger offsets to text & icon layers
/// ⚡ Fluid Canvas Painter applying dynamic structural stagger offsets to text & icon layers
class FluidFabPainter extends CustomPainter {
  final Color contentColor;
  final double progress; // 0.0 = collapsed, 1.0 = expanded

  FluidFabPainter({required this.contentColor, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    // Hard clip limits bounds instantly during layout snaps
    canvas.clipRect(Rect.fromLTWH(0, 0, size.width, size.height));

    // 1. Setup the Edit Icon
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

    // 2. Calculate coordinates based on original Row spacing specifications
    // Pin the icon exactly to the left spacing constant
    final double iconX = HomeConstants.fabCollapsedIconSpacing;
    final double iconY = (size.height - UIConstants.iconMD) / 2;

    iconPainter.paint(canvas, Offset(iconX, iconY));

    // 3. Smoothly Render 'New Note' Text utilizing Staggered Fade + Translate variables
    if (progress > 0.05) {
      // Curve tracking translates structural positions exponentially over time frames
      final double textFade = Curves.easeIn.transform(progress);
      final double slideOffset =
          (1.0 - progress) *
          -12.0; // Slides text into place gently from left to right

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

      // ⚡ FIX: The text baseline must start exactly AFTER the icon width and the padding gap
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
