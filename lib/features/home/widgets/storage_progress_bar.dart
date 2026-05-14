import 'package:flutter/material.dart';

class StorageProgressBar extends StatelessWidget {
  final double progress;
  final Color color;
  final double height;

  const StorageProgressBar({
    super.key,
    required this.progress,
    this.color = const Color(0xFF64B5F6),
    this.height = 32.0,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;
    final double effectiveProgress = (progress > 0 && progress < 0.01)
        ? 0.01
        : progress;
    return Container(
      height: height,
      width: double.infinity,
      padding: const EdgeInsets.all(4.0),
      decoration: BoxDecoration(
        color: Colors.transparent,
        border: Border.all(
          color: isDark ? colorScheme.primary : color,
          width: 3.0,
        ),
        borderRadius: BorderRadius.circular(height / 2),
      ),
      // The foolproof way: FractionalBox WITH a direct alignment anchor
      child: RepaintBoundary(
        child: TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0.0, end: effectiveProgress),
          duration: const Duration(milliseconds: 1200),
          curve: Curves.easeOutCubic,
          builder: (context, value, child) {
            return FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: value.clamp(0.0, 1.0),
              child: Container(
                // Regular container is fine here because Tween handles the math
                decoration: BoxDecoration(
                  color: progress > 0.9
                      ? Colors.redAccent
                      : (isDark ? Colors.white : colorScheme.primary),
                  borderRadius: BorderRadius.circular((height - 8) / 2),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
