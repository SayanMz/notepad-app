import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:notepad/features/note/widgets/voice_assistant_button.dart';
import 'package:notepad/features/note/controllers/note_controller.dart';

class NoteHeader extends StatelessWidget {
  const NoteHeader({
    super.key,
    required this.titleController,
    required this.onToggleEdit,
    required this.isEditing,
    required this.noteController,
    required this.lottieController,
    required this.isListening,
    required this.toggleListening,
  });

  final TextEditingController titleController;
  final VoidCallback onToggleEdit;
  final bool isEditing;
  final NoteController noteController;
  final AnimationController lottieController;
  final bool isListening;
  final VoidCallback toggleListening;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Removed unused colorScheme variable

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(
                  left: 12.0,
                  right: 8.0,
                  bottom: 12.0,
                ),
                child: TextField(
                  controller: titleController,
                  textAlign: TextAlign.start,
                  style: GoogleFonts.inter(
                    fontSize: 32,
                    height: 1.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
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
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  VoiceAssistantButton(
                    noteController: noteController,
                    lottieController: lottieController,
                    isListening: isListening,
                    toggleListening: toggleListening,
                  ),
                  IconButton(
                    onPressed: onToggleEdit,
                    icon: Icon(
                      Icons.auto_fix_high,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}
