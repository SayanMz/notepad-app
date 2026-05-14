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

  // features/home/widgets/home_fab.dart

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return SafeArea(
      child: ListenableBuilder(
        // 1. POSITION ISOLATION: Only listen to alignment changes here
        listenable: controller.fabAlignX,
        builder: (context, child) {
          final double alignX = controller.fabAlignX.value;

          return AnimatedAlign(
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeOutCubic,
            alignment: Alignment(
              alignX == 0.0 ? 0.0 : 0.95,
              isSelectionMode ? 1.5 : 0.95,
            ),
            // Use the cached child to prevent rebuilding the FAB during the glide
            child: child!,
          );
        },
        // 2. STATIC CHILD CACHING: Everything here is built once
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: OpenContainer(
            transitionType: ContainerTransitionType.fade,
            transitionDuration: UIConstants.animationExtraSlow,
            openColor: Theme.of(context).scaffoldBackgroundColor,
            closedColor: Colors.transparent,
            closedElevation: isSelectionMode ? 0 : UIConstants.elevationHigh,
            closedBuilder: (context, openContainer) => RepaintBoundary(
              // 3. REPAINT BOUNDARY: Caches the FAB pixels for the GPU
              child: ValueListenableBuilder<bool>(
                // 4. TARGETED REBUILD: Only the FAB width changes when extended
                valueListenable: controller.isFabExtended,
                builder: (context, isExtended, _) {
                  return InkWell(
                    onTap: openContainer,
                    borderRadius: BorderRadius.circular(16),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                      height: 60,
                      width: isExtended ? 140 : 65.0,
                      padding: EdgeInsets.symmetric(
                        horizontal: isExtended ? 20 : 0,
                      ),
                      decoration: BoxDecoration(
                        color: colorScheme.primary.withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.edit, color: Colors.white),
                          if (isExtended)
                            const Flexible(
                              child: Padding(
                                padding: EdgeInsets.only(left: 10.0),
                                child: FittedBox(
                                  child: Text(
                                    'New Note',
                                    maxLines: 1,
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
                  );
                },
              ),
            ),
            openBuilder: (context, _) => const NotePage(),
          ),
        ),
      ),
    );
  }
}
