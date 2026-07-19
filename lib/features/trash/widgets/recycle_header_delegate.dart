import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:notepad/core/extensions/context_extensions.dart';
import 'package:notepad/features/trash/recycle_constants.dart';

// Sliver header delegate keeps the recycle bin title pinned during scroll.
class SmoothHeaderDelegate extends SliverPersistentHeaderDelegate {
  final String title;
  final bool forceCentered;
  final VoidCallback onEmptyBin;

  SmoothHeaderDelegate({
    required this.title,
    required this.forceCentered,
    required this.onEmptyBin,
  });

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
    final bool isDark = context.isDark;
    final bool isOverlapping = shrinkOffset > 0.0;
    final double horizontalSlide = forceCentered
        ? 0.0
        : (shrinkOffset / RecycleConstants.headerSlideDistance).clamp(0.0, 1.0);
    final double alignX = forceCentered
        ? 0.0
        : ui.lerpDouble(0.0, -1.0, horizontalSlide)!;
    final double leftPadding = forceCentered
        ? 0.0
        : ui.lerpDouble(
            0.0,
            RecycleConstants.headerLeadingPadding,
            horizontalSlide,
          )!;

    return Material(
      color: isOverlapping
          ? (isDark ? const Color(0xFF2C2C2C) : const Color(0xFFF3F3F3))
          : context.colorScheme.surface,
      elevation: isOverlapping ? 4.0 : 0.0,
      animationDuration: const Duration(milliseconds: 200),
      shadowColor: isDark
          ? const Color(0xFF000000).withValues(alpha: 0.65)
          : const Color(0xFF2C2C2C).withValues(alpha: 0.15),
      child: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            const Align(alignment: Alignment.centerLeft, child: BackButton()),
            Align(
              alignment: Alignment(alignX, 0.0),
              child: Padding(
                padding: EdgeInsets.only(left: leftPadding),
                child: Text(
                  title,
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black,
                    fontWeight: FontWeight.bold,
                    fontSize: RecycleConstants.headerTitleFontSize,
                  ),
                ),
              ),
            ),
            if (!forceCentered)
              Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: const EdgeInsets.only(
                    right: RecycleConstants.headerActionRightPadding,
                  ),
                  child: IconButton(
                    icon: Icon(
                      Icons.delete_sweep,
                      color: isDark ? Colors.white70 : Colors.black54,
                      size: RecycleConstants.headerActionIconSize,
                    ),
                    onPressed: onEmptyBin,
                    tooltip: 'Empty Recycle Bin',
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant SmoothHeaderDelegate oldDelegate) {
    return oldDelegate.forceCentered != forceCentered;
  }
}
