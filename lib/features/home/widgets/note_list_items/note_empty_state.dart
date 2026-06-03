import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lottie/lottie.dart';
import 'package:notepad/core/constants/ui_constants.dart';
import 'package:notepad/features/filter/search_constants.dart';
import 'package:notepad/core/extensions/context_extensions.dart';

class NoteEmptyState extends StatelessWidget {
  const NoteEmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Lottie.asset(
            'assets/lotties/Ai_Robot.json',
            height: UIConstants.noteCardPreviewHeight,
            repeat: true,
            frameRate: const FrameRate(60),
            addRepaintBoundary: true,
            renderCache: RenderCache.drawingCommands,
            filterQuality: FilterQuality.medium,
          ),
          const SizedBox(height: UIConstants.paddingS),
          Text(
            "It’s awfully quiet in here",
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              fontSize: UIConstants.noteCardPreviewTitleFontSize,
              fontWeight: FontWeight.w700,
              color: context.isDark
                  ? Colors.white.withValues(alpha: 0.9)
                  : Colors.black87,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: UIConstants.paddingSM),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: SearchConstants.emptyHorizontalPadding,
            ),
            child: Text(
              "Feed me some notes so I can keep them safe for you.",
              textAlign: TextAlign.center,
              style: GoogleFonts.roboto(
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: Colors.grey,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
