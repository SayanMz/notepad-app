import 'package:animations/animations.dart';
import 'package:flutter/material.dart';
import 'package:notepad/core/constants/ui_constants.dart';
import 'package:notepad/features/home/controllers/home_controller.dart';
import 'package:notepad/features/note/note_page.dart';

class HomeFab extends StatelessWidget {
  final HomeController controller;
  final bool isSelectionMode;

  const HomeFab({
    super.key,
    required this.controller,
    required this.isSelectionMode,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListenableBuilder(
        listenable: Listenable.merge([
          controller.isFabExtended,
          controller.fabAlignX,
        ]),
        builder: (context, _) {
          final bool isExtended = controller.isFabExtended.value;
          final double alignX = controller.fabAlignX.value;

          return AnimatedAlign(
            // 500ms provides a smooth 'glide' across your monitor
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeOutCubic,
            // Selection mode slides it off-screen (1.5), otherwise follows alignX
            alignment: Alignment(
              alignX == 0.0 ? 0.0 : 0.95,
              isSelectionMode ? 1.5 : 0.95,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: OpenContainer(
                transitionType: ContainerTransitionType.fade,
                transitionDuration: UIConstants.animationExtraSlow,
                openColor: Theme.of(context).scaffoldBackgroundColor,
                closedColor: Colors.transparent,
                // Hide elevation when selection mode is active
                closedElevation: isSelectionMode
                    ? 0
                    : UIConstants.elevationHigh,
                closedBuilder: (context, openContainer) => InkWell(
                  onTap: openContainer,
                  borderRadius: BorderRadius.circular(16),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    height: 60,
                    width: isExtended ? 140 : 65.0,
                    // Adjust padding to maintain the circular/rectangular shape
                    padding: EdgeInsets.symmetric(
                      horizontal: isExtended ? 20 : 0,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.edit, color: Colors.white),
                        // AnimatedSize handles the 'New Note' text appearing/disappearing
                        if (isExtended)
                          Flexible(
                            // Wrap in Flexible to prevent Row overflow errors
                            child: Padding(
                              padding: const EdgeInsets.only(left: 10.0),
                              child: FittedBox(
                                child: const Text(
                                  'New Note',
                                  maxLines: 1, // Ensure text stays on one line
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                openBuilder: (context, _) => const NotePage(),
              ),
            ),
          );
        },
      ),
    );
  }
}
