import 'package:flutter/material.dart';
import 'package:notepad/core/constants/animation_constants.dart';
import 'package:notepad/core/extensions/context_extensions.dart';
import 'package:notepad/features/trash/recycle_constants.dart';

// Empty recycle state explains that no deleted notes are available.
class RecycleEmptyState extends StatefulWidget {
  final String text;

  const RecycleEmptyState({required this.text, super.key});

  @override
  State<RecycleEmptyState> createState() => _RecycleEmptyStateState();
}

class _RecycleEmptyStateState extends State<RecycleEmptyState> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final primaryColor = context.colorScheme.primary;
    final isDark = context.isDark;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          RepaintBoundary(
            child: GestureDetector(
              onTapDown: (_) => setState(() => _isPressed = true),
              onTapUp: (_) => setState(() => _isPressed = false),
              onTapCancel: () => setState(() => _isPressed = false),
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    _buildRipple(
                      RecycleConstants.emptyRippleOuterSize,
                      RecycleConstants.emptyRippleOuterPressedSize,
                      context.isDark ? 0.04 : 0.03,
                      AnimationConstants.slow,
                      Curves.easeOutBack,
                    ),
                    _buildRipple(
                      RecycleConstants.emptyRippleMiddleSize,
                      RecycleConstants.emptyRippleMiddlePressedSize,
                      context.isDark ? 0.06 : 0.05,
                      AnimationConstants.medium,
                      Curves.easeOutCubic,
                    ),
                    _buildRipple(
                      RecycleConstants.emptyRippleInnerSize,
                      RecycleConstants.emptyRippleInnerPressedSize,
                      context.isDark ? 0.09 : 0.08,
                      AnimationConstants.fast,
                      Curves.decelerate,
                    ),
                    AnimatedScale(
                      duration: AnimationConstants.fast,
                      curve: Curves.easeOutBack,
                      scale: _isPressed ? 1.2 : 1.0,
                      child: Icon(
                        Icons.delete_sweep_rounded,
                        size: RecycleConstants.emptyStateIconSize,
                        color: primaryColor.withValues(
                          alpha: isDark
                              ? RecycleConstants.emptyStateIconDarkAlpha
                              : RecycleConstants.emptyStateIconLightAlpha,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: RecycleConstants.emptyStateTextTopGap),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: RecycleConstants.emptyStateTextPaddingH,
            ),
            child: Text(
              widget.text,
              textAlign: TextAlign.center,
              style: context.textTheme.bodyMedium?.copyWith(
                color: isDark
                    ? Colors.white.withValues(
                        alpha: RecycleConstants.emptyStateBodyDarkAlpha,
                      )
                    : Colors.black.withValues(
                        alpha: RecycleConstants.emptyStateBodyLightAlpha,
                      ),
                fontWeight: FontWeight.w500,
                fontSize: RecycleConstants.emptyStateBodyFontSize,
                letterSpacing: RecycleConstants.emptyStateBodyLetterSpacing,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRipple(
    double size,
    double pressedSize,
    double alpha,
    Duration duration,
    Curve curve,
  ) {
    return AnimatedContainer(
      duration: duration,
      curve: curve,
      width: _isPressed ? pressedSize : size,
      height: _isPressed ? pressedSize : size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: context.colorScheme.primary.withValues(alpha: alpha),
      ),
    );
  }
}
