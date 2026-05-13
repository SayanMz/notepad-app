import 'package:flutter/material.dart';
import 'package:notepad/core/constants/ui_constants.dart';

/// ---------------------------------------------------------------------------
/// SAVE STATE ENUM
/// ---------------------------------------------------------------------------
enum SaveState { idle, saving, saved }

/// ---------------------------------------------------------------------------
/// SAVE INDICATOR WIDGET
/// ---------------------------------------------------------------------------
///
/// RESPONSIBILITY:
/// - Shows save status (Saving... -> Saved)
/// - Fully isolated to prevent unnecessary AppBar rebuilds
///
/// DESIGN:
/// - Uses ValueListenableBuilder for reactive updates
/// - AnimatedSwitcher for smooth transitions
class SaveIndicator extends StatelessWidget {
  const SaveIndicator({super.key, required this.saveState});

  final ValueNotifier<SaveState> saveState;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<SaveState>(
      valueListenable: saveState,
      builder: (context, state, _) {
        if (state == SaveState.idle) {
          return const SizedBox();
        }

        return AnimatedSwitcher(
          duration: UIConstants.animationFast,

          /// Smooth fade transition
          transitionBuilder: (child, animation) {
            return FadeTransition(opacity: animation, child: child);
          },

          child: state == SaveState.saving
              ? Row(
                  key: const ValueKey('saving'),
                  children: const [
                    SizedBox(
                      width: UIConstants.saveIndicatorSpinnerSize,
                      height: UIConstants.saveIndicatorSpinnerSize,
                      child: CircularProgressIndicator(
                        strokeWidth: UIConstants.toolbarColorCircleBorderWidth,
                      ),
                    ),
                    SizedBox(width: UIConstants.saveIndicatorSpacingSmall),
                    Text(
                      "Saving...",
                      style: TextStyle(
                        fontSize: UIConstants.saveIndicatorTextFontSize,
                      ),
                    ),
                  ],
                )
              : Row(
                  key: const ValueKey('saved'),
                  children: const [
                    Icon(
                      Icons.check,
                      size: UIConstants.saveIndicatorIconSize,
                      color: Colors.green,
                    ),
                    SizedBox(width: UIConstants.saveIndicatorSpacingTiny),
                    Text(
                      "Saved",
                      style: TextStyle(
                        fontSize: UIConstants.saveIndicatorTextFontSize,
                      ),
                    ),
                  ],
                ),
        );
      },
    );
  }
}
