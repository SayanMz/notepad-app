// Empty recycle state explains when there are no deleted notes to restore.
import 'package:flutter/material.dart';
import 'package:notepad/core/constants/animation_constants.dart';
import 'package:notepad/core/extensions/context_extensions.dart';
import 'package:notepad/features/trash/recycle_constants.dart';

// Empty recycle state explains when no deleted notes are available.
class RecycleEmptyState extends StatefulWidget {
  final String text;
  final bool isDark;

  const RecycleEmptyState({
    required this.text,
    required this.isDark,
    super.key,
  });

  @override
  State<RecycleEmptyState> createState() => _RecycleEmptyStateState();
}

class _RecycleEmptyStateState extends State<RecycleEmptyState> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final primaryColor = context.colorScheme.primary;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
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
                    AnimatedContainer(
                      duration: AnimationConstants.slow,
                      curve: Curves.easeOutBack,
                      width: _isPressed
                          ? RecycleConstants.emptyRippleOuterPressedSize
                          : RecycleConstants.emptyRippleOuterSize,
                      height: _isPressed
                          ? RecycleConstants.emptyRippleOuterPressedSize
                          : RecycleConstants.emptyRippleOuterSize,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: primaryColor.withValues(
                          alpha: widget.isDark ? 0.04 : 0.03,
                        ),
                      ),
                    ),
                    AnimatedContainer(
                      duration: AnimationConstants.medium,
                      curve: Curves.easeOutCubic,
                      width: _isPressed
                          ? RecycleConstants.emptyRippleMiddlePressedSize
                          : RecycleConstants.emptyRippleMiddleSize,
                      height: _isPressed
                          ? RecycleConstants.emptyRippleMiddlePressedSize
                          : RecycleConstants.emptyRippleMiddleSize,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: primaryColor.withValues(
                          alpha: widget.isDark ? 0.06 : 0.05,
                        ),
                      ),
                    ),
                    AnimatedContainer(
                      duration: AnimationConstants.fast,
                      curve: Curves.decelerate,
                      width: _isPressed
                          ? RecycleConstants.emptyRippleInnerPressedSize
                          : RecycleConstants.emptyRippleInnerSize,
                      height: _isPressed
                          ? RecycleConstants.emptyRippleInnerPressedSize
                          : RecycleConstants.emptyRippleInnerSize,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: primaryColor.withValues(
                          alpha: widget.isDark ? 0.09 : 0.08,
                        ),
                      ),
                    ),
                    AnimatedScale(
                      duration: AnimationConstants.fast,
                      curve: Curves.easeOutBack,
                      scale: _isPressed ? 1.2 : 1.0,
                      child: Icon(
                        Icons.delete_sweep_rounded,
                        size: RecycleConstants.emptyStateIconSize,
                        color: primaryColor.withValues(
                          alpha: widget.isDark
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
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: widget.isDark
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
}
