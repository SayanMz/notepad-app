import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:notepad/core/services/context_extensions.dart';
import 'package:notepad/features/note/note_constants.dart';

class NoteHeader extends StatelessWidget {
  NoteHeader({
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
    final isDark = context.isDark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
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
                        : Colors.black87,
                  ),
                  decoration: const InputDecoration(
                    hintText: 'Title',
                    hintStyle: TextStyle(color: Colors.grey),
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
                        // Toggle the state: true -> false, false -> true
                        _isClicked.value = !_isClicked.value;

                        // Trigger your edit logic
                        onToggleEdit();
                      },
                      icon: ShaderMask(
                        blendMode: BlendMode.srcIn,
                        shaderCallback: (Rect bounds) {
                          // Define the colors dynamically based on isDark and state
                          final List<Color> gradientColors;

                          if (_isClicked.value) {
                            // ⚡ Active "AI Magic" Gradient State
                            gradientColors = isDark
                                ? [
                                    const Color(0xFF9D4EDD),
                                    const Color(0xFF00F5D4),
                                  ] // Dark Mode: Neon Purple -> Cyan
                                : [
                                    const Color(0xFF6200EE),
                                    const Color(0xFF03DAC6),
                                  ]; // Light Mode: Deep Violet -> Teal
                          } else {
                            // 💤 Idle State (Matches your original fallback behavior)
                            gradientColors = isDark
                                ? [Colors.white, Colors.white70]
                                : [Colors.black, Colors.black87];
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
        ),
      ],
    );
  }
}
