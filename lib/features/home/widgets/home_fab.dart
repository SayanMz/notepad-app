import 'package:animations/animations.dart';
import 'package:flutter/material.dart';
import 'package:notepad/core/constants/animation_constants.dart';
import 'package:notepad/core/constants/ui_constants.dart';
import 'package:notepad/core/services/context_extensions.dart';
import 'package:notepad/core/theme/app_colors.dart';
import 'package:notepad/features/home/controllers/home_controller.dart';
import 'package:notepad/features/home/home_constants.dart';
import 'package:notepad/features/note/note_page.dart';

class HomeFab extends StatelessWidget {
  final HomeController controller;
  final bool isSelectionMode;

  const HomeFab({
    super.key,
    required this.controller,
    required this.isSelectionMode,
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

    // ⚡ Ultra-smooth fluid curve choice (emphasized ease-out)
    const Curve fluidCurve = Curves.easeOutBack;

    return SafeArea(
      child: AnimatedSlide(
        offset: isSelectionMode ? const Offset(0, 1.8) : Offset.zero,
        duration: AnimationConstants.medium,
        curve: Curves.fastOutSlowIn, // Smoother deceleration curve for exits
        child: ListenableBuilder(
          listenable: controller.fabAlignX,
          builder: (context, child) {
            final double alignX = controller.fabAlignX.value;

            return AnimatedAlign(
              duration: AnimationConstants.slow,
              curve: Curves.easeOutCubic,
              alignment: Alignment(alignX, HomeConstants.fabAlignDefaultY),
              child: child!,
            );
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: UIConstants.paddingXL,
            ),
            child: OpenContainer(
              transitionType: ContainerTransitionType.fadeThrough,
              transitionDuration: AnimationConstants.medium,
              openColor: Theme.of(context).scaffoldBackgroundColor,
              closedColor: Colors.transparent,
              closedElevation: isSelectionMode ? 0 : UIConstants.elevationHigh,
              closedShape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(
                  HomeConstants.fabClosedRadius,
                ),
              ),
              openShape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.zero,
              ),
              middleColor: Colors.transparent,

              closedBuilder: (context, openContainer) => RepaintBoundary(
                child: ValueListenableBuilder<bool>(
                  valueListenable: controller.isFabExtended,
                  builder: (context, isExtended, _) {
                    return AnimatedContainer(
                      duration: AnimationConstants.medium,
                      curve:
                          fluidCurve, // Added bouncy, organic physical scale response
                      height: fabHeight,
                      width: isExtended ? expandedWidth : collapsedWidth,
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(
                          HomeConstants.fabClosedRadius,
                        ),
                      ),
                      child: Material(
                        color: fabColor,
                        child: InkWell(
                          onTap: openContainer,
                          child: TweenAnimationBuilder<double>(
                            tween: Tween<double>(end: isExtended ? 1.0 : 0.0),
                            duration: AnimationConstants.fast,
                            curve: Curves.easeInOutCubic,
                            builder: (context, animationProgress, _) {
                              return CustomPaint(
                                size: Size(
                                  isExtended ? expandedWidth : collapsedWidth,
                                  fabHeight,
                                ),
                                painter: FluidFabPainter(
                                  contentColor: contentColor,
                                  progress: animationProgress,
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              openBuilder: (context, _) => const NotePage(),
            ),
          ),
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
