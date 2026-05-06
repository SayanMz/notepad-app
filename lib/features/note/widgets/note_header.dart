import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lottie/lottie.dart';
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
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      // 1. Force the Column to align everything to the left
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            // REMOVED: The leading SizedBox that was blocking the "very left" position
            Expanded(
              child: Padding(
                // 2. Adjust padding to be minimal on the left
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
                    letterSpacing:
                        -0.5, // Modern tech apps actually use slight negative spacing
                    color: isDark ? Colors.white70 : Colors.black87,
                  ),
                  decoration: const InputDecoration(
                    hintText: 'Title',
                    hintStyle: TextStyle(color: Colors.grey), //[cite: 3]
                    border: InputBorder.none,
                    focusedBorder: InputBorder.none, //[cite: 3]
                  ),
                ),
              ),
            ),
            // Use a Row instead of a Column to keep icons on the same line
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment:
                    CrossAxisAlignment.center, // Keep them level
                children: [
                  // 1. THE AI ASSISTANT
                  ValueListenableBuilder<bool>(
                    valueListenable: noteController.isProcessingVoice,
                    builder: (context, isProcessing, _) {
                      if (isProcessing) {
                        if (!lottieController.isAnimating) {
                          lottieController.repeat();
                        }
                      } else {
                        lottieController.stop();
                        lottieController.reset();
                      }

                      return GestureDetector(
                        onTap: (isProcessing && !isListening)
                            ? null
                            : toggleListening,
                        child: Lottie.asset(
                          'assets/lotties/Ai_Assistant.json',
                          controller: lottieController,
                          onLoaded: (composition) {
                            lottieController.duration = composition.duration;
                          },
                          // 44-48 is the "Golden Ratio" to match standard IconButton size
                          height: 48,
                          width: 48,
                        ),
                      );
                    },
                  ),

                  // 2. THE MAGIC WAND
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
