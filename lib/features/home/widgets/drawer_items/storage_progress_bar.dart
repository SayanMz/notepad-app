import 'package:flutter/material.dart';
import 'package:notepad/core/constants/animation_constants.dart';
import 'package:notepad/features/home/home_constants.dart';
import 'package:notepad/core/extensions/context_extensions.dart';
import 'package:notepad/core/theme/app_colors.dart';

// Animated progress bar that updates and animates Google Drive storage usage each time it opens.
class StorageProgressBar extends StatelessWidget {
  final double progress;
  final Color color;
  final double height;

  const StorageProgressBar({
    super.key,
    required this.progress,
    this.color = AppColors.storageProgress,
    this.height = HomeConstants.storageProgressHeight,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    final colorScheme = context.colorScheme;
    final double effectiveProgress =
        (progress > 0 && progress < HomeConstants.storageProgressMinIndicator)
        ? HomeConstants.storageProgressMinIndicator
        : progress;

    return Container(
      height: height,
      width: double.infinity,
      padding: const EdgeInsets.all(HomeConstants.storageProgressInnerPadding),
      decoration: BoxDecoration(
        color: Colors.transparent,
        border: Border.all(
          color: isDark ? colorScheme.primary : color,
          width: HomeConstants.storageProgressBorderWidth,
        ),
        borderRadius: BorderRadius.circular(height / 2),
      ),
      child: RepaintBoundary(
        child: TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0.0, end: effectiveProgress),
          duration: AnimationConstants.verySlow,
          curve: Curves.easeOutCubic,
          builder: (context, value, child) {
            return FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: value.clamp(0.0, 1.0),
              child: Container(
                decoration: BoxDecoration(
                  color: progress > 0.9
                      ? Colors.redAccent
                      : (isDark ? Colors.white : colorScheme.primary),
                  borderRadius: BorderRadius.circular(
                    (height - HomeConstants.storageProgressInnerInset) / 2,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
