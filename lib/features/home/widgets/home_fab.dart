import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:notepad/core/constants/animation_constants.dart';
import 'package:notepad/core/constants/ui_constants.dart';
import 'package:notepad/core/extensions/context_extensions.dart';
import 'package:notepad/features/home/controllers/home_fab_controller.dart';
import 'package:notepad/features/home/controllers/selection_controller.dart';
import 'package:notepad/features/home/home_constants.dart';
import 'package:notepad/features/note/note_page.dart';

// Animated floating action entry point for creating a new note.
class HomeFab extends StatelessWidget {
  const HomeFab({
    super.key,
    required this.fabController,
    required this.selectionController,
  });

  final HomeFabController fabController;
  final SelectionController selectionController;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListenableBuilder(
        listenable: Listenable.merge([
          fabController.alignX,
          fabController.isExtended,
        ]),
        builder: (context, _) {
          final bool isSelectionActive = selectionController.isSelectionMode;

          return AnimatedSlide(
            offset: isSelectionActive ? const Offset(0, 2.0) : Offset.zero,
            duration: AnimationConstants.medium,
            curve: Curves.fastOutSlowIn,
            child: AnimatedAlign(
              duration: AnimationConstants.slow,
              curve: Curves.easeOutCubic,
              alignment: Alignment(
                fabController.alignX.value,
                HomeConstants.fabAlignDefaultY,
              ),
              child: IgnorePointer(
                ignoring: isSelectionActive,
                child: _OptimizedMorphCanvas(
                  isExtended: fabController.isExtended.value,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _OptimizedMorphCanvas extends StatelessWidget {
  const _OptimizedMorphCanvas({required this.isExtended});

  final bool isExtended;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final isDark = context.isDark;
    final Color fabColor = isDark ? colorScheme.secondary : colorScheme.primary;
    final Color contentColor = isDark
        ? colorScheme.onSecondaryContainer.withValues(alpha: 0.8)
        : colorScheme.onPrimary;

    final double targetWidth = isExtended
        ? HomeConstants.fabExpandedWidth
        : HomeConstants.fabCollapsedWidth;

    return AnimatedContainer(
      duration: AnimationConstants.medium,
      curve: Curves.easeOutCubic,
      height: HomeConstants.fabHeight,
      width: targetWidth,
      child: RepaintBoundary(
        child: Material(
          color: fabColor,
          elevation: UIConstants.elevationHigh,
          borderRadius: BorderRadius.circular(HomeConstants.fabClosedRadius),
          child: InkWell(
            borderRadius: BorderRadius.circular(HomeConstants.fabClosedRadius),
            onTap: () {
              Navigator.of(context).push(_buildSharedAxisTransition());
            },
            splashColor: contentColor.withValues(alpha: 0.12),
            highlightColor: Colors.transparent,
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(end: isExtended ? 1.0 : 0.0),
              duration: AnimationConstants.medium,
              curve: Curves.easeOutCubic,
              builder: (context, progress, _) {
                // Computes live canvas width for smooth frame-by-frame rendering.
                final double currentWidth =
                    lerpDouble(
                      HomeConstants.fabCollapsedWidth,
                      HomeConstants.fabExpandedWidth,
                      progress,
                    ) ??
                    targetWidth;

                return CustomPaint(
                  size: Size(currentWidth, HomeConstants.fabHeight),
                  painter: FluidFabPainter(
                    contentColor: contentColor,
                    progress: progress,
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

Route _buildSharedAxisTransition() {
  return PageRouteBuilder(
    pageBuilder: (context, animation, secondaryAnimation) => const NotePage(),
    transitionDuration: AnimationConstants.medium,
    reverseTransitionDuration: AnimationConstants.snappy,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final scaleTween = Tween<double>(begin: 0.92, end: 1.0).animate(
        CurvedAnimation(parent: animation, curve: Curves.fastOutSlowIn),
      );
      final fadeTween = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
          parent: animation,
          curve: const Interval(
            0.0,
            AnimationConstants.sharedAxisFadeForwardCutoff,
            curve: Curves.easeOut,
          ),
        ),
      );

      return FadeTransition(
        opacity: fadeTween,
        child: ScaleTransition(scale: scaleTween, child: child),
      );
    },
  );
}

// Low-level painter to render morphing icon and text without extra layout work.
class FluidFabPainter extends CustomPainter {
  FluidFabPainter({required this.contentColor, required this.progress});

  final Color contentColor;
  final double progress;

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
