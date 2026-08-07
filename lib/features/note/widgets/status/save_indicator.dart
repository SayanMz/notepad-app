import 'package:flutter/material.dart';
import 'package:notepad/core/constants/animation_constants.dart';
import 'package:notepad/core/constants/editor_constants.dart';
import 'package:notepad/features/note/note_constants.dart';

enum SaveState { idle, saving, saved }

// Save indicator reflects the current persistence state in the note app bar.
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
          duration: AnimationConstants.fast,

          transitionBuilder: (child, animation) {
            return FadeTransition(opacity: animation, child: child);
          },

          child: state == SaveState.saving
              ? Row(
                  key: const ValueKey('saving'),
                  children: const [
                    SizedBox(
                      width: NoteConstants.saveIndicatorSpinnerSize,
                      height: NoteConstants.saveIndicatorSpinnerSize,
                      child: CircularProgressIndicator(
                        strokeWidth: EditorConstants.toolbarColorCircleBorderWidth,
                      ),
                    ),
                    SizedBox(width: NoteConstants.saveIndicatorSpacingSmall),
                    Text(
                      'Saving...',
                      style: TextStyle(
                        fontSize: NoteConstants.saveIndicatorTextFontSize,
                      ),
                    ),
                  ],
                )
              : Row(
                  key: const ValueKey('saved'),
                  children: const [
                    Icon(
                      Icons.check,
                      size: NoteConstants.saveIndicatorIconSize,
                      color: Colors.green,
                    ),
                    SizedBox(width: NoteConstants.saveIndicatorSpacingTiny),
                    Text(
                      'Saved',
                      style: TextStyle(
                        fontSize: NoteConstants.saveIndicatorTextFontSize,
                      ),
                    ),
                  ],
                ),
        );
      },
    );
  }
}
