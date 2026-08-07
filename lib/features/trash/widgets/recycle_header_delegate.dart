import 'package:flutter/material.dart';
import 'package:notepad/core/extensions/context_extensions.dart';
import 'package:notepad/features/trash/recycle_constants.dart';

/// Sliver header delegate that handles a clean, sequential cross-fade transition.
/// 
/// Transition stages based on scroll depth:
/// 1. Anchor: Hero title remains centered for the initial scroll window.
/// 2. Dissolve: Hero title fades out horizontally in-place.
/// 3. Bloom: Navigation title fades in at its fixed top-left position.
class SmoothHeaderDelegate extends SliverPersistentHeaderDelegate {
  final String title;
  final bool forceCentered;
  final VoidCallback onEmptyBin;
  final double scrollOffset;

  SmoothHeaderDelegate({
    required this.title,
    required this.forceCentered,
    required this.onEmptyBin,
    required this.scrollOffset,
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
    final double screenHeight = context.screenSize.height;

    // --- 1. App Bar Materialization Math ---
    // Start fading in the background surface after 4% scroll, complete by 8%.
    final double surfaceStart = screenHeight * 0.04;
    final double surfaceEnd = screenHeight * 0.08;
    final double surfaceProgress =
        ((scrollOffset - surfaceStart) / (surfaceEnd - surfaceStart))
            .clamp(0.0, 1.0);

    // --- 2. Title Sequence Math ---
    final double triggerStart = screenHeight * 0.10; // Start at 10%
    final double phaseStep = screenHeight * 0.06; // 6% Scroll Window

    // Opacity for the centered title - dissolves as scroll passes trigger threshold.
    final double centerOpacity = Curves.easeOut.transform(
      (1.0 - (scrollOffset - triggerStart) / phaseStep).clamp(0.0, 1.0),
    );

    // Opacity for the top-left title - blooms in almost immediately after hero dissolves.
    final double appearTrigger = triggerStart + (phaseStep * 1.15);
    final double topLeftOpacity = Curves.easeIn.transform(
      ((scrollOffset - appearTrigger) / phaseStep).clamp(0.0, 1.0),
    );

    // Dynamic surface color and elevation for smooth materialization.
    final Color baseTargetColor =
        context.isDark ? const Color(0xFF2C2C2C) : const Color(0xFFF3F3F3);
    final Color surfaceColor = Color.lerp(
      context.colorScheme.surface,
      baseTargetColor,
      surfaceProgress,
    )!;

    return Material(
      key: const ValueKey('smooth_header_material'),
      color: surfaceColor,
      elevation: surfaceProgress * 4.0,
      shadowColor: (context.isDark
              ? const Color(0xFF000000).withValues(alpha: 0.65)
              : const Color(0xFF2C2C2C).withValues(alpha: 0.15))
          .withValues(alpha: surfaceProgress),
      child: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            const Align(alignment: Alignment.centerLeft, child: BackButton()),
            
            // Render hero title if not fully dissolved.
            if (centerOpacity > 0.0)
              Opacity(
                opacity: centerOpacity,
                child: Center(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: context.isDark ? Colors.white : Colors.black,
                      fontWeight: FontWeight.bold,
                      fontSize: RecycleConstants.headerTitleFontSize,
                    ),
                  ),
                ),
              ),

            // Render navigation title if it has started blooming.
            if (!forceCentered && topLeftOpacity > 0.0)
              Opacity(
                opacity: topLeftOpacity,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 56.0),
                    child: Text(
                      title,
                      style: TextStyle(
                        color: context.isDark ? Colors.white : Colors.black,
                        fontWeight: FontWeight.bold,
                        fontSize: 20.0,
                      ),
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
                      color: context.isDark ? Colors.white70 : Colors.black54,
                      size: RecycleConstants.headerActionIconSize,
                    ),
                    onPressed: onEmptyBin,
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
    return oldDelegate.scrollOffset != scrollOffset ||
           oldDelegate.forceCentered != forceCentered ||
           oldDelegate.title != title;
  }
}
