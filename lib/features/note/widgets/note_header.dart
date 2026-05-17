import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:notepad/features/note/note_constants.dart';

class NoteHeader extends StatelessWidget {
  const NoteHeader({
    super.key,
    required this.titleController,
    required this.onToggleEdit,
    required this.readOnly,
  });

  final TextEditingController titleController;
  final VoidCallback onToggleEdit;
  final bool readOnly;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
                    fontWeight: FontWeight.w800,
                    letterSpacing: NoteConstants.titleLetterSpacing,
                    color: isDark ? Colors.white70 : Colors.black87,
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
                child: IconButton(
                  onPressed: onToggleEdit,
                  icon: Icon(
                    Icons.auto_fix_high,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
