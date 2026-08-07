import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:notepad/core/extensions/context_extensions.dart';
import 'package:notepad/features/note/note_constants.dart';

// Title bar for the note editor with title editing and edit-mode toggle action.
class NoteTitleBar extends StatelessWidget {
  NoteTitleBar({
    super.key,
    required this.titleController,
    required this.onToggleEdit,
    required this.readOnly,
  });

  final TextEditingController titleController;
  final VoidCallback onToggleEdit;
  final bool readOnly;

  final ValueNotifier<bool> _isClicked = ValueNotifier(true);

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final isDark = context.isDark;

    return Row(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(
              left: NoteConstants.titlePaddingLeft,
              right: NoteConstants.titlePaddingRight,
              bottom: NoteConstants.titlePaddingBottom,
            ),
            child: TextField(
              controller: titleController,
              textAlign: TextAlign.start,
              showCursor: !readOnly,
              style: GoogleFonts.inter(
                fontSize: NoteConstants.titleFontSize,
                height: NoteConstants.titleLineHeight,
                fontWeight: FontWeight.bold,
                letterSpacing: NoteConstants.titleLetterSpacing,
                color: isDark
                    ? Colors.white.withValues(alpha: 0.95)
                    : colorScheme.onSurface,
              ),
              decoration: InputDecoration(
                hintText: 'Title',
                hintStyle: TextStyle(color: colorScheme.onSurfaceVariant),
                border: InputBorder.none,
                focusedBorder: InputBorder.none,
              ),
            ),
          ),
        ),
        if (!readOnly)
          Padding(
            padding: const EdgeInsets.only(
              right: NoteConstants.titleIconPaddingRight,
            ),
            child: ListenableBuilder(
              listenable: _isClicked,
              builder: (context, child) {
                return IconButton(
                  onPressed: () {
                    _isClicked.value = !_isClicked.value;

                    onToggleEdit();
                  },
                  icon: ShaderMask(
                    blendMode: BlendMode.srcIn,
                    shaderCallback: (Rect bounds) {
                      final List<Color> gradientColors;

                      if (_isClicked.value) {
                        gradientColors = isDark
                            ? NoteConstants.titleGradientActiveDark
                            : NoteConstants.titleGradientActiveLight;
                      } else {
                        gradientColors = isDark
                            ? NoteConstants.titleGradientInactiveDark
                            : NoteConstants.titleGradientInactiveLight;
                      }

                      return LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: gradientColors,
                      ).createShader(bounds);
                    },
                    child: const Icon(Icons.auto_fix_high),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}
