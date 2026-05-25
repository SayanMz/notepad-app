import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:notepad/core/constants/animation_constants.dart';
import 'package:notepad/features/home/home_constants.dart';
import 'package:notepad/features/home/controllers/home_controller.dart';
import 'package:notepad/features/home/widgets/selection_toolbar.dart';

class SelectionOverlay extends StatelessWidget {
  final HomeController controller;
  final bool isSelectionMode;
  final bool isDark;
  final VoidCallback onShare;
  final VoidCallback onDelete;

  const SelectionOverlay({
    super.key,
    required this.controller,
    required this.isSelectionMode,
    required this.isDark,
    required this.onShare,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomCenter,
      // ⚡ THE SHARED-AXIS MORPH
      child: AnimatedSwitcher(
        duration: AnimationConstants.morph,
        switchInCurve: Curves.easeOutBack, // Pops up playfully
        switchOutCurve: Curves.easeInCubic, // Melts away smoothly
        transitionBuilder: (Widget child, Animation<double> animation) {
          return SizeTransition(
            sizeFactor: animation,
            axisAlignment:
                1.0, // Anchors the morph specifically to the bottom edge
            child: FadeTransition(opacity: animation, child: child),
          );
        },
        child: isSelectionMode
            ? SafeArea(
                key: const ValueKey('selection_toolbar_active'),
                child: Padding(
                  padding: const EdgeInsets.only(
                    left: HomeConstants.selectionOverlayPaddingL,
                    right: HomeConstants.selectionOverlayPaddingR,
                    bottom: HomeConstants.selectionOverlayPaddingB,
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(
                        HomeConstants.selectionOverlayRadius,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(
                            alpha: HomeConstants.selectionOverlayShadowAlpha,
                          ),
                          blurRadius: HomeConstants.selectionOverlayShadowBlur,
                          spreadRadius: 0,
                          offset: Offset(
                            0,
                            HomeConstants.selectionOverlayShadowOffsetY,
                          ),
                        ),
                      ],
                    ),
                    child: RepaintBoundary(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(
                          HomeConstants.selectionOverlayRadius,
                        ),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(
                            sigmaX: HomeConstants.selectionOverlayBlurSigma,
                            sigmaY: HomeConstants.selectionOverlayBlurSigma,
                          ),
                          child: Container(
                            decoration: BoxDecoration(
                              color: isDark
                                  ? Colors.black.withValues(
                                      alpha: HomeConstants
                                          .selectionOverlayDarkAlpha,
                                    )
                                  : Colors.white.withValues(
                                      alpha: HomeConstants
                                          .selectionOverlayLightAlpha,
                                    ),
                              borderRadius: BorderRadius.circular(
                                HomeConstants.selectionOverlayRadius,
                              ),
                              border: Border.all(
                                color: isDark
                                    ? Colors.white.withValues(
                                        alpha: HomeConstants
                                            .selectionOverlayBorderAlpha,
                                      )
                                    : Colors.white.withValues(
                                        alpha: HomeConstants
                                            .selectionOverlayBorderAlpha,
                                      ),
                                width:
                                    HomeConstants.selectionOverlayBorderWidth,
                              ),
                            ),
                            child: ListenableBuilder(
                              listenable: controller.selectionController,
                              builder: (context, _) {
                                return SelectionToolbar(
                                  isDark: isDark,
                                  allSelected: controller.isAllSelected,
                                  onSelectAll: (val) =>
                                      controller.toggleSelectAll(val),
                                  onShare: onShare,
                                  onDelete: onDelete,
                                  onColorChanged: (color) =>
                                      controller.updateSelectedColors(color),
                                  onPin: () => controller.togglePinBulk(),
                                  shouldPin: controller.showPinAction,
                                  selectedCount:
                                      controller.selectedNotes.length,
                                  controller: controller,
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              )
            : const SizedBox.shrink(
                key: ValueKey('selection_toolbar_hidden'),
              ), // Tells the switcher when to collapse
      ),
    );
  }
}
